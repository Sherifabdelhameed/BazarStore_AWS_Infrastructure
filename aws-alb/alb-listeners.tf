resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.my-app-lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks_target_group.arn
  }

  tags = {
    Name = "bazarstore-http-listener"
    Application = "BazarStore"
    Environment = "Production"
  }
}

# Comment out or remove the https listener
# resource "aws_lb_listener" "https" {...}

# Add additional target groups for different services if needed
resource "aws_lb_target_group" "catalog_target_group" {
  name        = "catalog-target-group"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200-399"
  }

  tags = {
    Name = "bazarstore-catalog-tg"
    Application = "BazarStore"
  }
}

resource "aws_lb_target_group" "order_target_group" {
  name        = "order-target-group"
  port        = 5001
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200-399"
  }

  tags = {
    Name = "bazarstore-order-tg"
    Application = "BazarStore"
  }
}

# Add listener rules for path-based routing
resource "aws_lb_listener_rule" "catalog_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.catalog_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/api/catalog*"]
    }
  }
}

resource "aws_lb_listener_rule" "order_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.order_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/api/order*"]
    }
  }
}