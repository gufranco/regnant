terraform {
  # Lower bound covers both:
  #   - the last MPL-licensed Terraform (1.5.x) for users who avoid the BSL switch
  #   - OpenTofu 1.6.x and newer
  # CI verifies on the latest stable line of each.
  required_version = ">= 1.17.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.6"
    }
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "~> 4.5"
    }
  }
}
