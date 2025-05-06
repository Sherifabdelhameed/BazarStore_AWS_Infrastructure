resource "aws_lb_target_group" "eks_target_group" {
  name        = "eks-target-group"
  port        = 30000 # Node port range starts at 30000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance" # For EKS nodes

  health_check {
    enabled             = true
    interval            = 30
    path                = "/healthz"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name = "eks-target-group"
  }
}