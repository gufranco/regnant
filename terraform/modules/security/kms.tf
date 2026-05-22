# Customer-managed KMS keys, one per concern. Rotation enabled on all.

resource "aws_kms_key" "this" {
  for_each = local.kms_purposes

  description              = each.value
  deletion_window_in_days  = 7
  enable_key_rotation      = true
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"

  tags = merge(local.module_tags, {
    Name    = "${var.name_prefix}-kms-${each.key}"
    purpose = each.key
  })
}

resource "aws_kms_alias" "this" {
  for_each = local.kms_purposes

  name          = "alias/${var.name_prefix}/${each.key}"
  target_key_id = aws_kms_key.this[each.key].key_id
}
