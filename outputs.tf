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