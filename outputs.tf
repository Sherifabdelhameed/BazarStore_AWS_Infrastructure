# Expose VPC ID for helm command
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.networking.vpc_id
}

# Expose ALB controller role ARN for helm command
output "alb_controller_role_arn" {
  description = "The ARN of the ALB controller IAM role"
  value       = module.aws-eks.alb_controller_role_arn
}

# Additional helpful outputs
output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.aws-eks.cluster_name
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = [module.networking.public_subnet1_id, module.networking.public_subnet2_id]
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = [module.networking.private_subnet1_id, module.networking.private_subnet2_id]
}

output "jenkins_instance_ip" {
  description = "Public IP of the Jenkins instance"
  value       = module.aws-ec2.jenkins_public_ip
}

output "kubernetes_config_cmd" {
  description = "Command to configure kubernetes context"
  value       = "aws eks update-kubeconfig --region eu-north-1 --name ${module.aws-eks.cluster_name}"
}

output "alb_security_group_id" {
  description = "The ID of the ALB security group"
  value       = module.aws-alb.alb_security_group_id
}

output "public_subnets_csv" {
  description = "Comma-separated list of public subnet IDs for ALB"
  value       = join(",", [module.networking.public_subnet1_id, module.networking.public_subnet2_id])
}

output "k8s_ingress_template_values" {
  description = "Values to use in your Kubernetes ingress manifest"
  value = {
    security_group_id = module.aws-alb.alb_security_group_id
    subnet_list      = join(",", [module.networking.public_subnet1_id, module.networking.public_subnet2_id])
  }
}