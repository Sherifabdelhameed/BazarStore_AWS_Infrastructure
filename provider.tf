terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.97.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = var.region
}

# Configure Kubernetes provider with EKS cluster details
provider "kubernetes" {
  host                   = module.aws-eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.aws-eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.aws-eks.cluster_name, "--region", var.region]
  }
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = module.aws-eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.aws-eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.aws-eks.cluster_name, "--region", var.region]
    }
  }
}

