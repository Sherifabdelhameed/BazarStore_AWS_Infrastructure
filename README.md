# BazarStore Infrastructure Project

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

### 4. Kubernetes Ingress & Service Exposure
- Application services exposed through Kubernetes ingress resources
- Traffic routing to appropriate backend services based on URL paths
- Health check configuration for high availability
- External connectivity through public-facing endpoints
- Path-based routing to microservices components

## Infrastructure Automation

### 1. Terraform Configuration
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

### 2. Ansible Automation
The project includes Ansible automation for infrastructure provisioning and configuration:

#### Directory Structure
```
ansible/
├── ansible.cfg           # Ansible configuration
├── docker-compose.yml    # Local development environment
├── inventory/            # Host inventory definitions
├── group_vars/           # Group-specific variables
├── playbooks/            # Ansible playbooks
│   └── site.yml          # Main playbook
└── roles/                # Role definitions
    ├── jenkins/          # Jenkins server role
    └── eks_node/         # EKS node role
```

#### Key Components
- **Local Development**: Docker-based test environment for development
- **Role-Based Design**: Modular roles for Jenkins and EKS nodes
- **Configuration Management**: Automated setup of services and dependencies
- **Security**: SSH key-based authentication and secure configurations

## Data Flow

1. External users access applications through Kubernetes ingress resources
2. Traffic is routed to appropriate backend services based on path patterns
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