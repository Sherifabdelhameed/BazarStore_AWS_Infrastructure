variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the EKS cluster"
  type        = string
}

variable "alb_controller_role_arn" {
  description = "ARN of the IAM role for ALB controller"
  type        = string
}

variable "alb_security_group_id" {
  description = "ID of the security group for ALB"
  type        = string
}

variable "enable_fallback" {
  description = "Enable fallback installation if Helm times out"
  type        = bool
  default     = false
}