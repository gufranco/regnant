variable "name_prefix" {
  description = "Prefix prepended to every named resource."
  type        = string
}

variable "realm_name" {
  description = "Keycloak realm name."
  type        = string
  default     = "regnant"
}

variable "display_name" {
  description = "Human-readable realm name."
  type        = string
  default     = "regnant local"
}

variable "access_token_lifespan" {
  description = "Lifetime of issued access tokens in seconds."
  type        = number
  default     = 900
}

variable "refresh_token_lifespan" {
  description = "Lifetime of refresh tokens in seconds."
  type        = number
  default     = 28800
}

variable "backends" {
  description = "Backend client identifiers to register against the realm."
  type        = list(string)
  default = [
    "backend-jira-clone",
    "backend-confluence-clone",
    "backend-bitbucket-clone",
  ]
}

variable "cli_client_id" {
  description = "Public CLI client id (device-code flow)."
  type        = string
  default     = "regnant-cli"
}

variable "tags" {
  description = "Identity tags only used for documentation."
  type        = map(string)
  default     = {}
}
