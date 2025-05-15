resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.eks_cluster.name  # Correct: match the resource in eks-cluster.tf
  node_group_name = "My-eks-nodes"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [var.az1, var.az2]
  
  instance_types  = ["t3.medium"]  # t3.micro is often too small for EKS
  
  disk_size       = 20
  
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }
  
  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling
  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]

  # Give time for k8s to deprovision properly
  timeouts {
    create = "30m"
    update = "30m" 
    delete = "30m"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Node security group
resource "aws_security_group" "eks_nodes" {
  name        = "eks-node-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-node-security-group"
  }
}

resource "aws_security_group_rule" "node_ingress_alb" {
  description              = "Allow ALB to communicate with nodes"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
  type                     = "ingress"
}

resource "aws_security_group_rule" "node_ingress_alb_sg" {
  description              = "Allow ALB security group to communicate with nodes"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = var.alb_security_group_id
  type                     = "ingress"
}

resource "aws_security_group_rule" "node_ingress_jenkins_ec2" {
  description              = "Allow Jenkins EC2 to communicate with EKS nodes"
  from_port                = 32259
  to_port                  = 32259
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = var.jenkins_security_group_id
  type                     = "ingress"
  
  # Add this lifecycle block to help with deletion
  lifecycle {
    create_before_destroy = true
  }
}

# Add specific rules for BazarStore application ports
resource "aws_security_group_rule" "allow_core_nodeport" {
  description              = "Allow traffic to Core service NodePort"
  from_port                = 30005
  to_port                  = 30005
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = var.alb_security_group_id
  type                     = "ingress"
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_catalog_port" {
  description              = "Allow traffic to Catalog service"
  from_port                = 5000
  to_port                  = 5000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = var.alb_security_group_id
  type                     = "ingress"
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_order_port" {
  description              = "Allow traffic to Order service"
  from_port                = 5001
  to_port                  = 5001
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = var.alb_security_group_id
  type                     = "ingress"
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_postgres_port" {
  description              = "Allow traffic to PostgreSQL service within cluster"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  self                     = true
  type                     = "ingress"
  
  lifecycle {
    create_before_destroy = true
  }
}

