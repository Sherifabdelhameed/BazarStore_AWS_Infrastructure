resource "aws_lb" "my-app-lb" {
  name               = "My-App-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ALB_SG.id]
  subnets            = var.subnets_private

  enable_deletion_protection = false

  tags = {
    Name = "My-ALB"
  }
}