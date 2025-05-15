output "jenkins_role_arn" {
  description = "The ARN of the Jenkins IAM role"
  value       = aws_iam_role.jenkins_eks_role.arn
}

output "jenkins_public_ip" {
  description = "The public IP of the Jenkins instance"
  value       = aws_eip.one.public_ip
}