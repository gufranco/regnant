# Autoscaling group keeps exactly var.envoy_instance_count instances.
# max_size is set above desired so the ASG can lifecycle-rotate during
# launch template changes without dropping below capacity.

resource "aws_autoscaling_group" "envoy" {
  name_prefix         = "${var.name_prefix}-envoy-"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.envoy_instance_count
  desired_capacity    = var.envoy_instance_count
  max_size            = var.envoy_instance_count * 2

  health_check_type         = "ELB"
  health_check_grace_period = 60
  default_cooldown          = 30
  termination_policies      = ["OldestLaunchTemplate", "OldestInstance"]
  capacity_rebalance        = true

  launch_template {
    id      = aws_launch_template.envoy.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 66
      instance_warmup        = 30
    }
    triggers = ["tag"]
  }

  dynamic "tag" {
    for_each = merge(local.module_tags, {
      Name    = "${var.name_prefix}-envoy"
      service = "envoy"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
