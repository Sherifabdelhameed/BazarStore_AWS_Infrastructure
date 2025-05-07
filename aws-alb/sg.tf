resource "aws_security_group" "ALB_SG" {
  name_prefix   = "alb-sg-"  # Using name_prefix instead of name
  description   = "Allow HTTP traffic and all outbound traffic"
  vpc_id        = var.vpc_id

  tags = {
    Name = "Depi"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.ALB_SG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.ALB_SG.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
