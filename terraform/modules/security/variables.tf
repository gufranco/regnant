variable "name_prefix" {
  description = "Prefix prepended to every named resource."
  type        = string
}

variable "region_label" {
  description = "Region label, used in CA subject and tags."
  type        = string
}

variable "vpc_id" {
  description = "VPC id from the network module. Used for security groups."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR for in-VPC ingress rules."
  type        = string
}

variable "domain_name" {
  description = "Public-facing domain. Used by ACM and CA leaf certs."
  type        = string
}

variable "tls_validity_hours" {
  description = "Validity window for the root CA and leaf certificates."
  type        = number
  default     = 8760
}

variable "mesh_services" {
  description = "Services that need an IAM role and an mTLS leaf certificate."
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
