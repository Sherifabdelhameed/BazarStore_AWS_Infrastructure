output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.my-app-lb.dns_name
}

output "lb_zone_id" {
  description = "The canonical hosted zone ID of the load balancer"
  value       = aws_lb.my-app-lb.zone_id
}

output "lb_arn" {
  description = "The ARN of the load balancer"
  value       = aws_lb.my-app-lb.arn
}

output "target_group_arn" {
  description = "The ARN of the target group"
  value       = aws_lb_target_group.eks_target_group.arn
}

output "alb_security_group_id" {
  description = "The ID of the ALB security group"
  value       = aws_security_group.ALB_SG.id
}

output "catalog_target_group_arn" {
  description = "The ARN of the catalog target group"
  value       = aws_lb_target_group.catalog_target_group.arn
}

output "order_target_group_arn" {
  description = "The ARN of the order target group"
  value       = aws_lb_target_group.order_target_group.arn
}

