# OSB state. Two tables: service_instances tracks provisioned LBs,
# service_bindings tracks credentials handed out per consuming app.

resource "aws_dynamodb_table" "service_instances" {
  name         = "${var.name_prefix}-service-instances"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "instance_id"

  attribute {
    name = "instance_id"
    type = "S"
  }

  attribute {
    name = "state"
    type = "S"
  }

  global_secondary_index {
    name            = "by-state"
    hash_key        = "state"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arns["dynamodb"]
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  deletion_protection_enabled = false

  tags = merge(local.module_tags, {
    Name = "${var.name_prefix}-service-instances"
  })
}

resource "aws_dynamodb_table" "service_bindings" {
  name         = "${var.name_prefix}-service-bindings"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "binding_id"
  range_key    = "instance_id"

  attribute {
    name = "binding_id"
    type = "S"
  }

  attribute {
    name = "instance_id"
    type = "S"
  }

  global_secondary_index {
    name            = "by-instance"
    hash_key        = "instance_id"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arns["dynamodb"]
  }

  deletion_protection_enabled = false

  tags = merge(local.module_tags, {
    Name = "${var.name_prefix}-service-bindings"
  })
}
