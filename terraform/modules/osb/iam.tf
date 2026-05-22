# Inline policies attached to the OSB API and OSB Worker roles created
# by the security module. Scoped to the specific tables, queues, and
# bucket this module creates.

data "aws_iam_role" "osb_api" {
  name = var.iam_role_names["osb-api"]
}

data "aws_iam_role" "osb_worker" {
  name = var.iam_role_names["osb-worker"]
}

data "aws_iam_role" "sovereign" {
  name = var.iam_role_names["sovereign"]
}

# OSB API: full RW on both tables, send to both queues, read S3 artifacts,
# KMS use on the dynamodb, sqs, and s3 keys.

data "aws_iam_policy_document" "osb_api" {
  statement {
    sid    = "DynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:DescribeTable",
    ]
    resources = [
      aws_dynamodb_table.service_instances.arn,
      "${aws_dynamodb_table.service_instances.arn}/index/*",
      aws_dynamodb_table.service_bindings.arn,
      "${aws_dynamodb_table.service_bindings.arn}/index/*",
    ]
  }

  statement {
    sid    = "Sqs"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [
      aws_sqs_queue.provision.arn,
      aws_sqs_queue.binding.arn,
    ]
  }

  statement {
    sid    = "S3Read"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.artifacts.arn,
      "${aws_s3_bucket.artifacts.arn}/*",
    ]
  }

  statement {
    sid    = "Kms"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = [
      var.kms_key_arns["dynamodb"],
      var.kms_key_arns["sqs"],
      var.kms_key_arns["s3"],
    ]
  }
}

resource "aws_iam_policy" "osb_api" {
  name        = "${var.name_prefix}-osb-api-data"
  description = "OSB API access to its tables, queues, and bucket."
  policy      = data.aws_iam_policy_document.osb_api.json
  tags        = local.module_tags
}

resource "aws_iam_role_policy_attachment" "osb_api" {
  role       = data.aws_iam_role.osb_api.name
  policy_arn = aws_iam_policy.osb_api.arn
}

# OSB Worker: same shape but writes to S3, consumes queues.

data "aws_iam_policy_document" "osb_worker" {
  statement {
    sid    = "DynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:DescribeTable",
    ]
    resources = [
      aws_dynamodb_table.service_instances.arn,
      "${aws_dynamodb_table.service_instances.arn}/index/*",
      aws_dynamodb_table.service_bindings.arn,
      "${aws_dynamodb_table.service_bindings.arn}/index/*",
    ]
  }

  statement {
    sid    = "Sqs"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [
      aws_sqs_queue.provision.arn,
      aws_sqs_queue.binding.arn,
    ]
  }

  statement {
    sid    = "S3Write"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.artifacts.arn,
      "${aws_s3_bucket.artifacts.arn}/*",
    ]
  }

  statement {
    sid    = "Kms"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = [
      var.kms_key_arns["dynamodb"],
      var.kms_key_arns["sqs"],
      var.kms_key_arns["s3"],
    ]
  }
}

resource "aws_iam_policy" "osb_worker" {
  name        = "${var.name_prefix}-osb-worker-data"
  description = "OSB Worker access to its tables, queues, and bucket."
  policy      = data.aws_iam_policy_document.osb_worker.json
  tags        = local.module_tags
}

resource "aws_iam_role_policy_attachment" "osb_worker" {
  role       = data.aws_iam_role.osb_worker.name
  policy_arn = aws_iam_policy.osb_worker.arn
}

# Sovereign reads from the artifact bucket for its S3 context plugin.

data "aws_iam_policy_document" "sovereign_artifacts_read" {
  statement {
    sid    = "ArtifactsRead"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.artifacts.arn,
      "${aws_s3_bucket.artifacts.arn}/*",
    ]
  }

  statement {
    sid    = "Kms"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = [var.kms_key_arns["s3"]]
  }
}

resource "aws_iam_policy" "sovereign_artifacts_read" {
  name        = "${var.name_prefix}-sovereign-artifacts-read"
  description = "Sovereign reads OSB artifacts as XDS context."
  policy      = data.aws_iam_policy_document.sovereign_artifacts_read.json
  tags        = local.module_tags
}

resource "aws_iam_role_policy_attachment" "sovereign_artifacts_read" {
  role       = data.aws_iam_role.sovereign.name
  policy_arn = aws_iam_policy.sovereign_artifacts_read.arn
}
