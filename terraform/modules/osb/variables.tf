variable "name_prefix" {
  description = "Prefix prepended to every named resource."
  type        = string
}

variable "artifact_bucket_name" {
  description = "Name of the S3 bucket holding OSB provisioning artifacts."
  type        = string
}

variable "kms_key_arns" {
  description = "KMS key ARNs from the security module, keyed by purpose."
  type        = map(string)
}

variable "iam_role_names" {
  description = "Mesh IAM role names from the security module, keyed by service."
  type        = map(string)
}

variable "sqs_visibility_timeout_seconds" {
  description = "Visibility timeout for the provisioning queues."
  type        = number
  default     = 90
}

variable "sqs_max_receive_count" {
  description = "Max receives before a message is moved to the DLQ."
  type        = number
  default     = 5
}

variable "dynamodb_billing_mode" {
  description = "Billing mode for the OSB tables."
  type        = string
  default     = "PAY_PER_REQUEST"
  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.dynamodb_billing_mode)
    error_message = "dynamodb_billing_mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "tags" {
  description = "Tags merged into every resource."
  type        = map(string)
  default     = {}
}
