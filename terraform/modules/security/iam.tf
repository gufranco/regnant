# IAM roles per service. Trust policy allows EC2 + ECS + Lambda + local
# containers to assume via STS GetCallerIdentity against LocalStack. A
# permission boundary caps the maximum scope; downstream modules attach
# fine-grained inline policies for the specific resources their service
# touches (S3 bucket, DynamoDB table, SQS queue, Secrets Manager paths).

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com",
        "ecs-tasks.amazonaws.com",
        "lambda.amazonaws.com",
      ]
    }
    effect = "Allow"
  }

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    effect = "Allow"
  }
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "permission_boundary" {
  statement {
    sid    = "AllowMeshObservabilityAndSecrets"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:CreateLogGroup",
      "cloudwatch:PutMetricData",
      "xray:PutTelemetryRecords",
      "xray:PutTraceSegments",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowS3DynamoDBSQSScopedByTag"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ChangeMessageVisibility",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/project"
      values   = [var.name_prefix]
    }
  }

  statement {
    sid    = "DenyIamAndKmsKeyAdmin"
    effect = "Deny"
    actions = [
      "iam:*",
      "kms:CreateKey",
      "kms:ScheduleKeyDeletion",
      "kms:DisableKey",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "permission_boundary" {
  name        = "${var.name_prefix}-permission-boundary"
  description = "Maximum scope a mesh service role may exercise."
  policy      = data.aws_iam_policy_document.permission_boundary.json
  tags        = local.module_tags
}

resource "aws_iam_role" "service" {
  for_each = toset(var.mesh_services)

  name                 = "${var.name_prefix}-${each.key}"
  description          = "Role assumed by the ${each.key} service."
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  permissions_boundary = aws_iam_policy.permission_boundary.arn
  max_session_duration = 3600

  tags = merge(local.module_tags, {
    Name    = "${var.name_prefix}-${each.key}"
    service = each.key
  })
}

# A baseline observability policy attached to every service role so
# every container can write logs and metrics without needing a custom
# policy first.

data "aws_iam_policy_document" "observability_baseline" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:CreateLogGroup",
      "cloudwatch:PutMetricData",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "observability_baseline" {
  name        = "${var.name_prefix}-observability-baseline"
  description = "Logs + metrics baseline attached to every mesh role."
  policy      = data.aws_iam_policy_document.observability_baseline.json
  tags        = local.module_tags
}

resource "aws_iam_role_policy_attachment" "observability_baseline" {
  for_each   = toset(var.mesh_services)
  role       = aws_iam_role.service[each.key].name
  policy_arn = aws_iam_policy.observability_baseline.arn
}

# Sovereign needs to read every leaf secret. Bundle that into a dedicated
# policy attached only to the sovereign role.

data "aws_iam_policy_document" "sovereign_secrets_read" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "secretsmanager:Name"
      values   = ["${var.name_prefix}/*"]
    }
  }
}

resource "aws_iam_policy" "sovereign_secrets_read" {
  name        = "${var.name_prefix}-sovereign-secrets-read"
  description = "Sovereign reads leaf bundles for SDS."
  policy      = data.aws_iam_policy_document.sovereign_secrets_read.json
  tags        = local.module_tags
}

resource "aws_iam_role_policy_attachment" "sovereign_secrets_read" {
  role       = aws_iam_role.service["sovereign"].name
  policy_arn = aws_iam_policy.sovereign_secrets_read.arn
}

# Each service role can read its own leaf bundle from Secrets Manager.

data "aws_iam_policy_document" "service_own_secret" {
  for_each = toset(var.mesh_services)

  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_secretsmanager_secret.leaf_bundle[each.key].arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_secretsmanager_secret.ca_cert.arn]
  }
}

resource "aws_iam_policy" "service_own_secret" {
  for_each = toset(var.mesh_services)

  name        = "${var.name_prefix}-${each.key}-own-secret"
  description = "Read this service's own mTLS leaf bundle."
  policy      = data.aws_iam_policy_document.service_own_secret[each.key].json
  tags = merge(local.module_tags, {
    service = each.key
  })
}

resource "aws_iam_role_policy_attachment" "service_own_secret" {
  for_each   = toset(var.mesh_services)
  role       = aws_iam_role.service[each.key].name
  policy_arn = aws_iam_policy.service_own_secret[each.key].arn
}
