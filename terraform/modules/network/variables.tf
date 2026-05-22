variable "name_prefix" {
  description = "Prefix prepended to every named resource (e.g., regnant)."
  type        = string
}

variable "region_label" {
  description = "Region label used to derive AZ names."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.42.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDRs for the three public subnets, one per AZ."
  type        = list(string)
  default     = ["10.42.0.0/20", "10.42.16.0/20", "10.42.32.0/20"]
  validation {
    condition     = length(var.public_subnet_cidrs) == 3
    error_message = "Provide exactly three public subnet CIDRs."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDRs for the three private subnets, one per AZ."
  type        = list(string)
  default     = ["10.42.64.0/20", "10.42.80.0/20", "10.42.96.0/20"]
  validation {
    condition     = length(var.private_subnet_cidrs) == 3
    error_message = "Provide exactly three private subnet CIDRs."
  }
}

variable "enable_vpc_endpoints" {
  description = "Whether to create VPC endpoints for S3, DynamoDB, and SQS."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags merged into every resource."
  type        = map(string)
  default     = {}
}
