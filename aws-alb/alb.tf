resource "aws_lb" "my-app-lb" {
  name               = "My-App-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ALB_SG.id]
  subnets            = var.subnets_public

  enable_deletion_protection = false

  # Add this lifecycle block to ensure proper cleanup
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "My-ALB"
  }
}