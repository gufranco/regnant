variable "name_prefix" {
  description = "Prefix prepended to every named resource."
  type        = string
}

variable "region_label" {
  description = "Region label used in tags."
  type        = string
}

variable "vpc_id" {
  description = "VPC id."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets the ASG and NLB attach to."
  type        = list(string)
}

variable "envoy_instance_count" {
  description = "Number of Envoy instances to keep in the fleet."
  type        = number
  default     = 3
  validation {
    condition     = var.envoy_instance_count >= 1 && var.envoy_instance_count <= 50
    error_message = "envoy_instance_count must be between 1 and 50."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the fleet."
  type        = string
  default     = "c7i.large"
}

variable "ami_owner" {
  description = "AMI owner filter for the launch template data source."
  type        = string
  default     = "self"
}

variable "ami_name_pattern" {
  description = "AMI name pattern matching the Packer-built image."
  type        = string
  default     = "regnant-envoy-*"
}

variable "fallback_ami_id" {
  description = "AMI id to use when no Packer image is registered yet. LocalStack's default ami-* placeholders."
  type        = string
  default     = "ami-12345678"
}

variable "key_pair_name" {
  description = "EC2 key pair name from the security module."
  type        = string
}

variable "envoy_security_group_id" {
  description = "Security group id for Envoy instances."
  type        = string
}

variable "envoy_iam_role_name" {
  description = "IAM role name the Envoy instances assume."
  type        = string
}

variable "leaf_secret_arn" {
  description = "ARN of the Envoy mTLS leaf secret. Read at boot."
  type        = string
}

variable "ca_secret_arns" {
  description = "Root CA secret ARNs from the security module."
  type        = map(string)
}

variable "kms_key_arns" {
  description = "KMS key ARNs from the security module."
  type        = map(string)
}

variable "sovereign_xds_endpoint" {
  description = "URL Envoys use to fetch dynamic resources from Sovereign."
  type        = string
  default     = "sovereign:8080"
}

variable "otel_collector_endpoint" {
  description = "OTel Collector OTLP endpoint."
  type        = string
  default     = "http://otel-collector:4317"
}

variable "tags" {
  description = "Tags merged into every resource."
  type        = map(string)
  default     = {}
}
