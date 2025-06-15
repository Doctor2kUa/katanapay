##########################
# main.tf
##########################

# AWS Provider
provider "aws" {
  region = var.region
}

# Create VPC and subnets via Terraform AWS VPC module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 3.0.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.azs.names
  public_subnets  = var.public_subnets_cidrs
  private_subnets = var.private_subnets_cidrs

  tags = {
    Name        = "${var.cluster_name}-vpc"
    Environment = var.environment
  }
}

data "aws_availability_zones" "azs" {}

# EKS Cluster with IRSA enabled via Terraform AWS EKS module
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = ">= 18.0.0"

  cluster_name    = var.cluster_name
  cluster_version = var.k8s_version

  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      desired_size   = 2
      max_size       = 3
      min_size       = 1
      instance_types = ["t3.medium"]
    }
  }

  enable_irsa = true
}

# Data sources for IRSA
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_iam_openid_connect_provider" "oidc" {
  url = replace(
    data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer,
    "https://",
    ""
  )
}

# Local values for IRSA policy
locals {
  oidc_provider = data.aws_iam_openid_connect_provider.oidc.arn
  oidc_issuer   = replace(
    data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer,
    "https://",
    ""
  )
  sa_subject    = "system:serviceaccount/${var.namespace}/${var.service_account_name}"
}

# IAM Role for nginx pod IRSA
resource "aws_iam_role" "nginx_irsa" {
  name = "${var.cluster_name}-nginx-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Federated = local.oidc_provider },
      Action    = "sts:AssumeRoleWithWebIdentity",
      Condition = { StringEquals = { "${local.oidc_issuer}:sub" = local.sa_subject } }
    }]
  })
}

# IAM Policy granting read access to S3
resource "aws_iam_policy" "nginx_s3_read" {
  name        = "${var.cluster_name}-nginx-s3-read"
  description = "Allow nginx pod to read from s3://${var.bucket_name}/${var.location}"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["s3:ListBucket", "s3:GetObject"],
      Resource = [
        "arn:aws:s3:::${var.bucket_name}",
        "arn:aws:s3:::${var.bucket_name}/${trim(var.location, "/")}/*"
      ]
    }]
  })
}

# Attach the policy to the IRSA role
resource "aws_iam_role_policy_attachment" "nginx_irsa_attach" {
  role       = aws_iam_role.nginx_irsa.name
  policy_arn = aws_iam_policy.nginx_s3_read.arn
}

# Kubernetes provider to deploy ServiceAccount & Deployment
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Kubernetes ServiceAccount annotated for IRSA
resource "kubernetes_service_account" "nginx_sa" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.nginx_irsa.arn
    }
  }
}

# Deploy nginx using that ServiceAccount
resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx"
    namespace = var.namespace
    labels = { app = "nginx" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "nginx" } }
    template {
      metadata { labels = { app = "nginx" } }
      spec {
        service_account_name = kubernetes_service_account.nginx_sa.metadata[0].name
        container {
          name  = "nginx"
          image = "nginx:latest"
          port { container_port = 80 }
        }
      }
    }
  }
}    
