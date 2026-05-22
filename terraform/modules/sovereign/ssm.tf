# SSM parameters Sovereign reads at startup. The container's entrypoint
# pulls these into its config.yaml so the runtime image stays generic
# and the per-environment values live in AWS.

resource "aws_ssm_parameter" "artifact_bucket" {
  name        = "${local.ssm_prefix}/artifact_bucket"
  description = "S3 bucket holding XDS context artifacts."
  type        = "String"
  value       = var.artifact_bucket_name
  tags        = local.module_tags
}

resource "aws_ssm_parameter" "artifact_prefix" {
  name        = "${local.ssm_prefix}/artifact_prefix"
  description = "Prefix inside the artifact bucket Sovereign scans."
  type        = "String"
  value       = var.artifact_prefix
  tags        = local.module_tags
}

resource "aws_ssm_parameter" "redis_url" {
  name        = "${local.ssm_prefix}/redis_url"
  description = "Redis URL used for caching and leader election."
  type        = "SecureString"
  key_id      = var.kms_key_arns["secrets"]
  value       = var.redis_url
  tags        = local.module_tags
}

resource "aws_ssm_parameter" "log_level" {
  name        = "${local.ssm_prefix}/log_level"
  description = "Sovereign log level."
  type        = "String"
  value       = var.log_level
  tags        = local.module_tags
}

resource "aws_ssm_parameter" "matched_service" {
  name        = "${local.ssm_prefix}/matched_service"
  description = "node.id pattern matched against connecting Envoys."
  type        = "String"
  value       = var.matched_service
  tags        = local.module_tags
}

resource "aws_ssm_parameter" "refresh_interval" {
  name        = "${local.ssm_prefix}/refresh_interval_seconds"
  description = "How often Sovereign re-reads its context source."
  type        = "String"
  value       = tostring(var.refresh_interval_seconds)
  tags        = local.module_tags
}

resource "aws_ssm_parameter" "leaf_secret_arns_json" {
  name        = "${local.ssm_prefix}/leaf_secret_arns"
  description = "JSON map of service name to leaf bundle ARN."
  type        = "String"
  value       = jsonencode(var.leaf_secret_arns)
  tags        = local.module_tags
}

resource "aws_ssm_parameter" "ca_secret_arn" {
  name        = "${local.ssm_prefix}/ca_secret_arn"
  description = "ARN of the root CA public certificate secret."
  type        = "String"
  value       = var.ca_secret_arns["cert"]
  tags        = local.module_tags
}
