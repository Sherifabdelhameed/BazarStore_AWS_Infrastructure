terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = ">= 2.4.1"
    }
  }
}

resource "kubernetes_service_account" "aws_lbc" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.alb_controller_role_arn
    }
  }
}

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
 

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "false"  // Change from "true" to "false"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.alb_controller_role_arn
  }

  set {
    name  = "logLevel"
    value = "debug"  // Increase logging detail
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  timeout    = 1800  # 30 minutes instead of 600s (10 minutes)
  wait       = true

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [kubernetes_service_account.aws_lbc]
}

resource "null_resource" "alb_controller_fallback" {
  count = var.enable_fallback ? 1 : 0
  
  triggers = {
    helm_failed = helm_release.aws_lb_controller.id
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for nodes to be ready
      kubectl wait --for=condition=ready node --all --timeout=300s
      
      # Install ALB Controller manually
      helm install aws-load-balancer-controller \
        eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=${var.cluster_name} \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set region=${var.region} \
        --set vpcId=${var.vpc_id} \
        --timeout 20m
    EOT
    
    on_failure = continue
  }
  
  depends_on = [helm_release.aws_lb_controller]
}