variable "name_prefix" {
  description = "Prefix prepended to every named resource."
  type        = string
}

variable "region_label" {
  description = "Region label used in tags and SSM parameter paths."
  type        = string
}

variable "artifact_bucket_name" {
  description = "S3 bucket Sovereign's context plugin reads from."
  type        = string
}

variable "artifact_prefix" {
  description = "Prefix inside the artifact bucket Sovereign scans."
  type        = string
  default     = "envoy-resources/"
}

variable "leaf_secret_arns" {
  description = "Per-service mTLS leaf secret ARNs from the security module."
  type        = map(string)
}

variable "ca_secret_arns" {
  description = "Root CA secret ARNs (cert and key) from the security module."
  type        = map(string)
}

variable "kms_key_arns" {
  description = "KMS key ARNs from the security module."
  type        = map(string)
}

variable "iam_role_names" {
  description = "Service role names from the security module."
  type        = map(string)
}

variable "redis_url" {
  description = "Redis URL Sovereign uses for cache + leader election."
  type        = string
  default     = "redis://redis:6379/0"
}

variable "log_level" {
  description = "Log level for the Sovereign process."
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], var.log_level)
    error_message = "log_level must be one of DEBUG, INFO, WARNING, ERROR."
  }
}

variable "matched_service" {
  description = "node.id pattern Sovereign matches Envoys against."
  type        = string
  default     = "envoy-*"
}

variable "refresh_interval_seconds" {
  description = "How often Sovereign re-reads its S3 context."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags merged into every resource."
  type        = map(string)
  default     = {}
}
