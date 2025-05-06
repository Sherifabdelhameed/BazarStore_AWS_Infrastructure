resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.my-app-lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks_target_group.arn
  }
}

# Comment out or remove the https listener
# resource "aws_lb_listener" "https" {...}