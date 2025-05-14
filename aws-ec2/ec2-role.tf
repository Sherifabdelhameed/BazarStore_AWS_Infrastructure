# IAM Role for Jenkins EC2 to access EKS
resource "aws_iam_role" "jenkins_eks_role" {
  name = "jenkins-eks-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "jenkins-ec2-eks-access-role"
  }
}

# Attach necessary policies for EKS access
resource "aws_iam_role_policy_attachment" "jenkins_eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.jenkins_eks_role.name
}

# Use AmazonEKSWorkerNodePolicy for node group access
resource "aws_iam_role_policy_attachment" "jenkins_eks_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.jenkins_eks_role.name
}

# Use correct ARN for ECR access
resource "aws_iam_role_policy_attachment" "jenkins_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.jenkins_eks_role.name
}

# Add policy for kubectl operations
resource "aws_iam_policy" "eks_kubectl_policy" {
  name        = "EksKubectlPolicy"
  description = "Policy for using kubectl with EKS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:UpdateClusterConfig",
          "eks:DescribeUpdate"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_kubectl_policy_attachment" {
  policy_arn = aws_iam_policy.eks_kubectl_policy.arn
  role       = aws_iam_role.jenkins_eks_role.name
}

# Create an instance profile with the role
resource "aws_iam_instance_profile" "jenkins_instance_profile" {
  name = "jenkins-eks-instance-profile"
  role = aws_iam_role.jenkins_eks_role.name
}