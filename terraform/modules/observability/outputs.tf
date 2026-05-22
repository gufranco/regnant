output "archive_bucket_name" {
  description = "S3 bucket archiving long-term logs and traces."
  value       = aws_s3_bucket.archive.id
}

output "archive_bucket_arn" {
  description = "Archive bucket ARN."
  value       = aws_s3_bucket.archive.arn
}

output "log_group_names" {
  description = "CloudWatch log group names keyed by service."
  value = {
    for svc, lg in aws_cloudwatch_log_group.service : svc => lg.name
  }
}

output "log_group_arns" {
  description = "CloudWatch log group ARNs keyed by service."
  value = {
    for svc, lg in aws_cloudwatch_log_group.service : svc => lg.arn
  }
}
