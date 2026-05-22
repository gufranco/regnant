# Each service role gets write access to its own log group and the
# archive bucket, plus permission to use the logs KMS key.

data "aws_iam_role" "service" {
  for_each = toset(var.log_groups)
  name     = var.iam_role_names[each.key]
}

data "aws_iam_policy_document" "service_logs" {
  for_each = toset(var.log_groups)

  statement {
    sid    = "LogGroup"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = [
      aws_cloudwatch_log_group.service[each.key].arn,
      "${aws_cloudwatch_log_group.service[each.key].arn}:*",
    ]
  }

  statement {
    sid    = "Kms"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = [var.kms_key_arns["logs"]]
  }

  statement {
    sid    = "ArchiveBucket"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetBucketLocation",
    ]
    resources = [
      "${aws_s3_bucket.archive.arn}/${each.key}/*",
    ]
  }
}

resource "aws_iam_policy" "service_logs" {
  for_each = toset(var.log_groups)

  name        = "${var.name_prefix}-${each.key}-logs"
  description = "Writes logs and archive shards for ${each.key}."
  policy      = data.aws_iam_policy_document.service_logs[each.key].json
  tags = merge(local.module_tags, {
    service = each.key
  })
}

resource "aws_iam_role_policy_attachment" "service_logs" {
  for_each   = toset(var.log_groups)
  role       = data.aws_iam_role.service[each.key].name
  policy_arn = aws_iam_policy.service_logs[each.key].arn
}
