variable "name_prefix" {
  description = "Prefix prepended to every named resource."
  type        = string
}

variable "domain_name" {
  description = "Public-facing domain (apex)."
  type        = string
}

variable "subdomains" {
  description = "Additional subdomains to attach via aliases (e.g., api, console)."
  type        = list(string)
  default     = ["api", "console", "edge"]
}

variable "vpc_id" {
  description = "VPC id for the private hosted zone association."
  type        = string
}

variable "nlb_dns_name" {
  description = "DNS name of the NLB the edge fronts."
  type        = string
}

variable "nlb_zone_id" {
  description = "Hosted zone id for the NLB (for Route53 alias)."
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM cert for the CloudFront viewer."
  type        = string
}

variable "cache_default_ttl" {
  description = "Default cache TTL in seconds."
  type        = number
  default     = 60
}

variable "cache_max_ttl" {
  description = "Maximum cache TTL in seconds."
  type        = number
  default     = 3600
}

variable "tags" {
  description = "Tags merged into every resource."
  type        = map(string)
  default     = {}
}
