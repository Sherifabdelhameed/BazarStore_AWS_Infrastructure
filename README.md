Collecting workspace information# AWS Infrastructure Architecture Project Overview

This Terraform project implements a comprehensive AWS infrastructure featuring a multi-tier architecture with various AWS services working together. The design follows best practices for security, scalability, and availability.

## Architecture Components

### 1. Networking Layer (aws-networking-vpc)
- **VPC**: Main network container with CIDR block `10.0.0.0/16`
- **Subnets**:
  - Public subnets (10.0.0.0/24, 10.0.2.0/24) in two AZs
  - Private subnets (10.0.1.0/24, 10.0.3.0/24) in two AZs
- **Gateways**:
  - Internet Gateway for public internet access
  - NAT Gateway in public subnet for private subnet outbound connectivity
- **Routing**:
  - Public route table directing internet traffic to IGW
  - Private route table directing internet traffic through NAT Gateway

### 2. Compute Layer (aws-ec2)
- Jenkins server deployed in public subnet 2
- t3.micro instance with fixed private IP (10.0.2.100)
- Security group allowing SSH (port 22) and Jenkins (port 8080) traffic
- Elastic IP for static public access
- SSH key pair for secure access

### 3. Container Orchestration (aws-eks)
- EKS cluster spanning private subnets
- Control plane with public/private endpoint access
- Worker nodes (2 desired, min 1, max 3) in private subnets
- Cluster security group for control plane communication
- Node security group for worker node traffic
- AWS Load Balancer Controller for dynamic ALB provisioning

### 4. Load Balancing Layer (aws-alb)
- External-facing Application Load Balancer
- Security group allowing HTTP/HTTPS traffic
- Target group for EKS node ports (30000)
- HTTP listener routing traffic to applications
- Health check configuration for high availability

## Data Flow

1. External users access applications through the ALB
2. ALB forwards requests to containers running on EKS nodes
3. Jenkins server provides CI/CD capabilities for application deployment
4. Private EKS nodes can access the internet via NAT Gateway
5. Admin access to EKS API is available through the public endpoint

## Security Design

- Public resources (Jenkins, ALB) in public subnets with specific traffic allowed
- Private resources (EKS nodes) in private subnets without direct internet access
- Security groups limiting traffic to necessary ports
- IAM roles with least privilege permissions for EKS components

This architecture represents a production-grade AWS infrastructure with proper isolation, scalability, and security considerations.
