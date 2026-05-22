locals {
  module_tags = merge(var.tags, {
    "regnant.module" = "security"
  })

  kms_purposes = {
    s3       = "regnant S3 bucket envelope encryption"
    dynamodb = "regnant DynamoDB tables encryption"
    sqs      = "regnant SQS queues encryption"
    secrets  = "regnant Secrets Manager envelope"
    logs     = "regnant CloudWatch Logs encryption"
  }
}
