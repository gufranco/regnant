# Two task queues, each with its own DLQ + redrive policy.

resource "aws_sqs_queue" "provision_dlq" {
  name                              = "${var.name_prefix}-provision-tasks-dlq"
  message_retention_seconds         = 1209600
  kms_master_key_id                 = var.kms_key_arns["sqs"]
  kms_data_key_reuse_period_seconds = 300

  tags = merge(local.module_tags, {
    Name = "${var.name_prefix}-provision-tasks-dlq"
    role = "dlq"
  })
}

resource "aws_sqs_queue" "provision" {
  name                              = "${var.name_prefix}-provision-tasks"
  visibility_timeout_seconds        = var.sqs_visibility_timeout_seconds
  message_retention_seconds         = 345600
  receive_wait_time_seconds         = 20
  kms_master_key_id                 = var.kms_key_arns["sqs"]
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.provision_dlq.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })

  tags = merge(local.module_tags, {
    Name = "${var.name_prefix}-provision-tasks"
  })
}

resource "aws_sqs_queue" "binding_dlq" {
  name                              = "${var.name_prefix}-binding-tasks-dlq"
  message_retention_seconds         = 1209600
  kms_master_key_id                 = var.kms_key_arns["sqs"]
  kms_data_key_reuse_period_seconds = 300

  tags = merge(local.module_tags, {
    Name = "${var.name_prefix}-binding-tasks-dlq"
    role = "dlq"
  })
}

resource "aws_sqs_queue" "binding" {
  name                              = "${var.name_prefix}-binding-tasks"
  visibility_timeout_seconds        = var.sqs_visibility_timeout_seconds
  message_retention_seconds         = 345600
  receive_wait_time_seconds         = 20
  kms_master_key_id                 = var.kms_key_arns["sqs"]
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.binding_dlq.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })

  tags = merge(local.module_tags, {
    Name = "${var.name_prefix}-binding-tasks"
  })
}

# Queue policies: only the OSB API can send, only the OSB Worker can
# receive. ARNs reference the roles created by the security module.

data "aws_iam_policy_document" "provision_queue_policy" {
  statement {
    sid     = "OsbApiSend"
    effect  = "Allow"
    actions = ["sqs:SendMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_role.osb_api.arn]
    }
    resources = [aws_sqs_queue.provision.arn]
  }

  statement {
    sid    = "OsbWorkerReceive"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_role.osb_worker.arn]
    }
    resources = [aws_sqs_queue.provision.arn]
  }
}

resource "aws_sqs_queue_policy" "provision" {
  queue_url = aws_sqs_queue.provision.url
  policy    = data.aws_iam_policy_document.provision_queue_policy.json
}

data "aws_iam_policy_document" "binding_queue_policy" {
  statement {
    sid     = "OsbApiSend"
    effect  = "Allow"
    actions = ["sqs:SendMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_role.osb_api.arn]
    }
    resources = [aws_sqs_queue.binding.arn]
  }

  statement {
    sid    = "OsbWorkerReceive"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_role.osb_worker.arn]
    }
    resources = [aws_sqs_queue.binding.arn]
  }
}

resource "aws_sqs_queue_policy" "binding" {
  queue_url = aws_sqs_queue.binding.url
  policy    = data.aws_iam_policy_document.binding_queue_policy.json
}
