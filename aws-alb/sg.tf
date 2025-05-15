resource "aws_security_group" "ALB_SG" {
  name_prefix   = "alb-sg-"
  description   = "Security group for BazarStore ALB"
  vpc_id        = var.vpc_id

  revoke_rules_on_delete = true
  
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "eks-ingress-alb-sg"
    ManagedBy = "terraform"
    Purpose = "ALB for BazarStore applications"
    Application = "BazarStore"
    Environment = "Production"
  }
}

# Allow HTTP traffic from anywhere
resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.ALB_SG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
  description       = "Allow HTTP traffic for BazarStore frontend"
}

# Allow outbound traffic to all destinations
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.ALB_SG.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"
}
