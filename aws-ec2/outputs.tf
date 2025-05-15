output "jenkins_role_arn" {
    description = "The ARN of the Jenkins IAM role"
    value = aws_iam_role.jenkins_eks_role.arn
  
}