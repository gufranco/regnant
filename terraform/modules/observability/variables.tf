variable "name_prefix" {
  description = "Prefix prepended to every named resource."
  type        = string
}

variable "region_label" {
  description = "Region label, used in tags."
  type        = string
}

variable "archive_bucket_name" {
  description = "Name of the S3 bucket archiving long-term logs and traces."
  type        = string
  default     = null
}

variable "kms_key_arns" {
  description = "KMS ARN map from the security module."
  type        = map(string)
}

variable "iam_role_names" {
  description = "Service role names from the security module."
  type        = map(string)
}

variable "log_retention_days" {
  description = "Retention period in days for CloudWatch log groups."
  type        = number
  default     = 30
}

variable "archive_ia_days" {
  description = "Days before transitioning archive objects to Infrequent Access."
  type        = number
  default     = 30
}

variable "archive_glacier_days" {
  description = "Days before transitioning archive objects to Glacier."
  type        = number
  default     = 90
}

variable "archive_expire_days" {
  description = "Days before archive objects expire."
  type        = number
  default     = 365
}

variable "log_groups" {
  description = "CloudWatch log group names to create per service."
  type        = list(string)
  default = [
    "osb-api",
    "osb-worker",
    "sovereign",
    "envoy",
    "auth-sidecar",
    "ratelimit",
    "backend-jira-clone",
    "backend-confluence-clone",
    "backend-bitbucket-clone",
  ]
}

variable "tags" {
  description = "Tags merged into every resource."
  type        = map(string)
  default     = {}
}
