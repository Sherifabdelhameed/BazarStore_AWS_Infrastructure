Collecting workspace information# AWS Infrastructure - Enterprise-Grade Multi-Tier Architecture

This Terraform project implements a robust AWS infrastructure featuring a multi-tier architecture with various AWS services working together. The design follows best practices for security, scalability, and high availability.

## Architecture Components

### 1. Networking Layer (aws-networking-vpc)
- **VPC**: Main network container with CIDR block `10.0.0.0/16`
- **Subnets**:
  - Public subnets (10.0.0.0/24, 10.0.2.0/24) across two AZs
  - Private subnets (10.0.1.0/24, 10.0.3.0/24) across two AZs
- **Gateways**:
  - Internet Gateway for public subnet internet access
  - NAT Gateway in public subnet for private subnet outbound connectivity
- **Routing**:
  - Public route tables directing internet traffic through IGW
  - Private route tables directing internet traffic through NAT Gateway

### 2. Compute Layer (aws-ec2)
- Jenkins CI/CD server deployed in public subnet 2
- t3.micro instance with fixed private IP (10.0.2.100)
- Security group allowing SSH (port 22) and Jenkins (port 8080) traffic
- Elastic IP for stable public access
- SSH key pair for secure administration

### 3. Container Orchestration (aws-eks)
- EKS cluster spanning private subnets for security
- Control plane with both public/private endpoint access
- Worker nodes (2x t3.medium) running in private subnets
- Auto-scaling configuration (min: 1, desired: 2, max: 3)
- Custom security groups for cluster and node communication
- IAM roles with least privilege permissions

### 4. Load Balancing Layer (aws-alb)
- External-facing Application Load Balancer in **public** subnets
- Security group allowing HTTP inbound traffic
- Target group configured for EKS node port 30000
- HTTP listener routing traffic to containerized applications
- Custom health check configuration for high availability
- Automatic registration of EKS nodes using Terraform data sources

## Infrastructure Deployment

The project uses Terraform's S3 backend to store state remotely:
```
terraform {
  backend "s3" {
    bucket = "depiproject-tfstate"
    key    = "terraform.tfstate"
    region = "eu-north-1"
  }
}
```

## Data Flow

1. External users access applications through the ALB's public endpoint
2. ALB forwards requests directly to worker nodes on port 30000
3. Jenkins server in public subnet manages CI/CD pipelines
4. Private EKS nodes access internet via NAT Gateway for updates/packages
5. Administrators can access EKS control plane via public endpoint

## Security Design

- **Network Segmentation**: Critical workloads in private subnets
- **Least Privilege**: IAM roles scoped to minimum required permissions
- **Traffic Control**: Security groups limiting traffic to necessary ports and sources
- **SSH Security**: Key-based authentication for EC2 access
- **Logging**: EKS control plane logs enabled for audit and troubleshooting

This architecture represents a production-grade AWS infrastructure with proper isolation, scalability, and security considerations suitable for enterprise applications.