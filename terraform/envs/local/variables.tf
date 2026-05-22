# Inputs for the local LocalStack environment.
# Every value has a sensible default so `tofu apply` works with no flags.

variable "localstack_endpoint" {
  description = "Base URL where the LocalStack container is reachable."
  type        = string
  default     = "http://localhost:4566"
}

variable "region_label" {
  description = "The synthetic AWS region we use locally. Mirrors the value drawn on the canvas."
  type        = string
  default     = "us-east-1"
}

variable "envoy_instance_count" {
  description = "Number of Envoy instances to provision. Default 3; production would be ~150."
  type        = number
  default     = 3
  validation {
    condition     = var.envoy_instance_count >= 1 && var.envoy_instance_count <= 50
    error_message = "envoy_instance_count must be between 1 and 50."
  }
}

variable "domain_name" {
  description = "Fully-qualified domain used by Route53 + CloudFront + ACM."
  type        = string
  default     = "regnant.local"
}

variable "osb_artifact_bucket_name" {
  description = "Name of the S3 bucket holding OSB provisioning artifacts (Sovereign context source)."
  type        = string
  default     = "regnant-osb-artifacts"
}

variable "enable_otel_traces" {
  description = "Toggle to disable trace export. Metrics and logs are always on."
  type        = bool
  default     = true
}

variable "tls_validity_hours" {
  description = "Validity window for the regnant local CA and leaf certificates."
  type        = number
  default     = 8760
}

variable "keycloak_realm" {
  description = "Keycloak realm name. Matches the realm-export.json shipped in identity/keycloak/."
  type        = string
  default     = "regnant"
}

variable "keycloak_url" {
  description = "Keycloak base URL (admin endpoint)."
  type        = string
  default     = "http://localhost:8090"
}

variable "keycloak_admin_username" {
  description = "Keycloak bootstrap admin username."
  type        = string
  default     = "admin"
}

variable "keycloak_admin_password" {
  description = "Keycloak bootstrap admin password (local dev only)."
  type        = string
  default     = "changeme"
  sensitive   = true
}

variable "osb_broker_username" {
  description = "OSB API basic-auth username (local dev only)."
  type        = string
  default     = "broker"
}

variable "osb_broker_password" {
  description = "OSB API basic-auth password (local dev only)."
  type        = string
  default     = "changeme"
  sensitive   = true
}

variable "ratelimit_redis_db" {
  description = "Redis logical database id used by Steward."
  type        = number
  default     = 1
}

variable "sovereign_redis_db" {
  description = "Redis logical database id used by Sovereign."
  type        = number
  default     = 0
}

variable "ami_image_tag" {
  description = "Docker tag of the Envoy AMI-equivalent image produced by Packer (ADR-0006)."
  type        = string
  default     = "regnant/envoy-fleet:local"
}
