# One CloudWatch log group per service so AWS-native tooling (and any
# operator who finds the AWS console first) sees a familiar layout.

resource "aws_cloudwatch_log_group" "service" {
  for_each = toset(var.log_groups)

  name              = "/regnant/${each.key}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arns["logs"]

  tags = merge(local.module_tags, {
    Name    = "${var.name_prefix}-${each.key}-logs"
    service = each.key
  })
}
