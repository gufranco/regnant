output "ssm_prefix" {
  description = "SSM parameter path prefix Sovereign reads on startup."
  value       = local.ssm_prefix
}

output "ssm_parameter_arns" {
  description = "ARNs of every SSM parameter this module creates."
  value = {
    artifact_bucket  = aws_ssm_parameter.artifact_bucket.arn
    artifact_prefix  = aws_ssm_parameter.artifact_prefix.arn
    redis_url        = aws_ssm_parameter.redis_url.arn
    log_level        = aws_ssm_parameter.log_level.arn
    matched_service  = aws_ssm_parameter.matched_service.arn
    refresh_interval = aws_ssm_parameter.refresh_interval.arn
    leaf_secret_arns = aws_ssm_parameter.leaf_secret_arns_json.arn
    ca_secret_arn    = aws_ssm_parameter.ca_secret_arn.arn
  }
}

output "config_summary" {
  description = "Effective Sovereign configuration values, sourced from inputs."
  value = {
    artifact_bucket          = var.artifact_bucket_name
    artifact_prefix          = var.artifact_prefix
    redis_url                = var.redis_url
    log_level                = var.log_level
    matched_service          = var.matched_service
    refresh_interval_seconds = var.refresh_interval_seconds
  }
  sensitive = false
}
