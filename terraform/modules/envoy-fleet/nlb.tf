# Network Load Balancer fronts the Envoy fleet. TCP 443 listener
# forwards to a TCP 10000 target group attached to the ASG.

resource "aws_lb" "envoy" {
  name               = "${var.name_prefix}-envoy"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true

  tags = merge(local.module_tags, {
    Name = "${var.name_prefix}-envoy-nlb"
  })
}

resource "aws_lb_target_group" "envoy" {
  name        = "${var.name_prefix}-envoy"
  port        = 10000
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  deregistration_delay = 30

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/ready"
    port                = "9901"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    timeout             = 5
    matcher             = "200-299"
  }

  tags = merge(local.module_tags, {
    Name = "${var.name_prefix}-envoy-tg"
  })
}

resource "aws_lb_listener" "envoy" {
  load_balancer_arn = aws_lb.envoy.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.envoy.arn
  }
}

resource "aws_autoscaling_attachment" "envoy" {
  autoscaling_group_name = aws_autoscaling_group.envoy.name
  lb_target_group_arn    = aws_lb_target_group.envoy.arn
}
