resource "aws_eks_cluster" "eks_cluster" {
  name = "My-eks-cluster"

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"  # More compatible with kubectl
  }

  role_arn = aws_iam_role.cluster.arn
  version  = "1.31"

  vpc_config {
    subnet_ids = [
      var.az1,
      var.az2
    ]
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  # Optional: Enable logging
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]

  tags = {
    Name = "DEPI-EKS-CLUSTER"
  }
}

resource "aws_iam_role" "cluster" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# Allow IAM user to access the cluster
resource "aws_eks_access_entry" "sherif_admin_access" {
  cluster_name      = aws_eks_cluster.eks_cluster.name
  principal_arn     = "arn:aws:iam::537124967157:user/SherifAbdelhameed"
  type              = "STANDARD"
}

# Associate the IAM user with the EKS Admin Policy for full admin access
resource "aws_eks_access_policy_association" "sherif_admin_policy" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  principal_arn = "arn:aws:iam::537124967157:user/SherifAbdelhameed"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.sherif_admin_access]
}

# Admin View Policy
resource "aws_eks_access_policy_association" "sherif_admin_view_policy" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminViewPolicy"
  principal_arn = "arn:aws:iam::537124967157:user/SherifAbdelhameed"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.sherif_admin_access]
}

# Allow Jenkins Role to access the EKS cluster
resource "aws_eks_access_entry" "jenkins_access" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = var.jenkins_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "jenkins_admin_policy" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = var.jenkins_role_arn
  
  access_scope {
    type = "cluster"
  }
  
  depends_on = [aws_eks_access_entry.jenkins_access]
}

