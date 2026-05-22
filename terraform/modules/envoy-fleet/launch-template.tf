# Launch template + instance profile for the Envoy fleet.

resource "aws_iam_instance_profile" "envoy" {
  name = "${var.name_prefix}-envoy-instance-profile"
  role = var.envoy_iam_role_name
  tags = local.module_tags
}

resource "aws_launch_template" "envoy" {
  name_prefix   = "${var.name_prefix}-envoy-"
  image_id      = local.resolved_ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  iam_instance_profile {
    name = aws_iam_instance_profile.envoy.name
  }

  vpc_security_group_ids = [var.envoy_security_group_id]

  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type           = "gp3"
      volume_size           = 20
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = var.kms_key_arns["s3"]
    }
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh.tmpl", {
    leaf_secret_arn         = var.leaf_secret_arn
    ca_cert_secret_arn      = var.ca_secret_arns["cert"]
    sovereign_xds_endpoint  = var.sovereign_xds_endpoint
    otel_collector_endpoint = var.otel_collector_endpoint
    region_label            = var.region_label
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.module_tags, {
      Name    = "${var.name_prefix}-envoy"
      service = "envoy"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.module_tags, {
      Name = "${var.name_prefix}-envoy-root"
    })
  }

  tags = local.module_tags

  lifecycle {
    create_before_destroy = true
  }
}
