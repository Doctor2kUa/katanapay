##########################
# variables.tf
##########################

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "katana-dev-eks"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "dev"
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.27"
}

variable "vpc_cidr" {
  description = "CIDR for new VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets_cidrs" {
  description = "Public subnet CIDRs per AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets_cidrs" {
  description = "Private subnet CIDRs per AZ"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
}

variable "location" {
  description = "Path prefix in the bucket"
  type        = string
  default     = "/"
}

variable "namespace" {
  description = "Kubernetes namespace for nginx"
  type        = string
  default     = "default"
}

variable "service_account_name" {
  description = "Name of the Kubernetes ServiceAccount"
  type        = string
  default     = "nginx-sa"
}
