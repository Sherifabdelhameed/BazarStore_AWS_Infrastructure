resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.eks_cluster.name  # Correct: match the resource in eks-cluster.tf
  node_group_name = "My-eks-nodes"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [var.az1, var.az2]
  
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