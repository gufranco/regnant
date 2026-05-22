# Local environment composition.
# Each module corresponds to one canvas region. Modules are added
# progressively across the plan's phases. Phase 2 ships this skeleton
# so `tofu init && tofu validate` work today.

locals {
  common_tags = {
    project     = "regnant"
    environment = "local"
    region      = var.region_label
  }
}

module "network" {
  source       = "../../modules/network"
  name_prefix  = "regnant"
  region_label = var.region_label
  tags         = local.common_tags
}

# Phase 4: security module (KMS, IAM, KeyPair, ACM, local CA).
# module "security" {
#   source = "../../modules/security"
#   ...
# }

# Phase 5: OSB module (S3, DynamoDB, SQS).
# module "osb" {
#   source = "../../modules/osb"
#   ...
# }

# Phase 6: Sovereign module (SSM parameters, IAM role, health gate).
# module "sovereign" {
#   source = "../../modules/sovereign"
#   ...
# }

# Phase 7: Envoy fleet module (Launch Template, ASG, NLB, Target Group).
# module "envoy_fleet" {
#   source = "../../modules/envoy-fleet"
#   ...
# }

# Phase 9: Edge module (Route53, CloudFront/nginx).
# module "edge" {
#   source = "../../modules/edge"
#   ...
# }

# Phase 10: Observability module (S3 archive, IAM, lifecycle).
# module "observability" {
#   source = "../../modules/observability"
#   ...
# }

# Phase 20: Identity module (Keycloak realm + clients).
# module "identity" {
#   source = "../../modules/identity"
#   ...
# }
