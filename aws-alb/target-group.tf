resource "aws_lb_target_group" "eks_target_group" {
  name        = "eks-target-group"
  port        = 30005  # Match the NodePort from core-service.yaml
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance" # For EKS nodes

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200-399"  # Allow more response codes for health checks
  }

  # Add stickiness for better user experience
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = {
    Name = "bazarstore-target-group"
    Application = "BazarStore"
    Environment = "Production"
  }
}