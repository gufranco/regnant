output "artifact_bucket_name" {
  description = "S3 bucket name holding OSB provisioning artifacts."
  value       = aws_s3_bucket.artifacts.id
}

output "artifact_bucket_arn" {
  description = "S3 bucket ARN."
  value       = aws_s3_bucket.artifacts.arn
}

output "instances_table_name" {
  description = "DynamoDB table for service instances."
  value       = aws_dynamodb_table.service_instances.name
}

output "instances_table_arn" {
  description = "DynamoDB instances table ARN."
  value       = aws_dynamodb_table.service_instances.arn
}

output "bindings_table_name" {
  description = "DynamoDB table for service bindings."
  value       = aws_dynamodb_table.service_bindings.name
}

output "bindings_table_arn" {
  description = "DynamoDB bindings table ARN."
  value       = aws_dynamodb_table.service_bindings.arn
}

output "provision_queue_url" {
  description = "SQS URL for the provisioning queue."
  value       = aws_sqs_queue.provision.url
}

output "provision_queue_arn" {
  description = "SQS ARN for the provisioning queue."
  value       = aws_sqs_queue.provision.arn
}

output "binding_queue_url" {
  description = "SQS URL for the binding queue."
  value       = aws_sqs_queue.binding.url
}

output "binding_queue_arn" {
  description = "SQS ARN for the binding queue."
  value       = aws_sqs_queue.binding.arn
}

output "provision_dlq_url" {
  description = "Dead-letter queue for provisioning tasks."
  value       = aws_sqs_queue.provision_dlq.url
}

output "binding_dlq_url" {
  description = "Dead-letter queue for binding tasks."
  value       = aws_sqs_queue.binding_dlq.url
}
