resource "aws_lb" "my-app-lb" {
  name               = "My-App-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_HTTPS_and_HTTPS_public_access.id]
  subnets            = var.subnets_private

  enable_deletion_protection = true

  tags = {
    Name = "My-ALB"
  }
}