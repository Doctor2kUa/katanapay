# High Level Automation Plan

- Automate any tasks that could block the creation of isolated environments.
- Implement CI/CD pipelines for deployments.
- Configure event triggers and audit logging.
graph LR
  subgraph VPC["VPC (PCI-DSS Aligned)"]
  
    %% Public Zone
    subgraph Public_Subnet ["Public Subnet"]
      direction TB
      Internet["Internet Users"]
      Internet -->|"HTTPS (maybe over VPN)"| WAF["AWS WAF"]
      WAF --> ALB["ALB / CloudFront"]
    end

    %% Application Zone (PCI Workload)
    subgraph App_Subnet ["Application Subnet"]
      direction TB
      ALB --> EKS["Amazon EKS Cluster"]
      EKS --> AppPods["nginx app"]
    end

    %% Monitoring Zone (Restricted)
    subgraph Monitoring_Subnet ["Monitoring Subnet"]
      direction TB
      AppPods --> Prom["Prometheus"]
      Prom --> Grafana["Grafana (in EKS)"]
      Grafana -->|reads creds via| SM["Secrets Manager"]
      AppPods --> Fluentd["Fluentd"]
      Fluentd --> Loki["Loki"]
      Grafana -->|Loki data source| Loki
      EKS -->|push metrics| CW["CloudWatch Metrics"]
      Grafana -->|CloudWatch data source| CW
      SM["Secrets Manager"] --> AppPods
    end

    %% IaC & Key Management (Unified)
    subgraph IaC_and_Security ["IaC & Key Management"]
      direction TB
      CodeCommit["AWS CodeCommit\n(Terraform repo)"] -->|push configs| Terraform["Terraform"]
      Terraform --> WAF
      Terraform --> ALB
      Terraform --> EKS
      Terraform --> SM["Secrets Manager"]
      SM -->|CMKs| KMS["AWS KMS"]
      Terraform --> KMS
    end

  end

  style Public_Subnet fill:#f9f9f9,stroke:#333,stroke-width:1px
  style App_Subnet fill:#ffecec,stroke:#333,stroke-width:1px
  style Monitoring_Subnet fill:#eef,stroke:#333,stroke-width:1px
  style IaC_and_Security fill:#fff4e5,stroke:#333,stroke-width:1px

