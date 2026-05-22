# Local environment composition. Each module owns one logical area of
# the platform; modules compose here and share outputs via this file.

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

module "security" {
  source             = "../../modules/security"
  name_prefix        = "regnant"
  region_label       = var.region_label
  vpc_id             = module.network.vpc_id
  vpc_cidr           = module.network.vpc_cidr
  domain_name        = var.domain_name
  tls_validity_hours = var.tls_validity_hours
  tags               = local.common_tags
}

module "osb" {
  source               = "../../modules/osb"
  name_prefix          = "regnant"
  artifact_bucket_name = var.osb_artifact_bucket_name
  kms_key_arns         = module.security.kms_key_arns
  iam_role_names       = module.security.iam_role_names
  tags                 = local.common_tags
}

module "sovereign" {
  source               = "../../modules/sovereign"
  name_prefix          = "regnant"
  region_label         = var.region_label
  artifact_bucket_name = module.osb.artifact_bucket_name
  leaf_secret_arns     = module.security.leaf_secret_arns
  ca_secret_arns       = module.security.ca_secret_arns
  kms_key_arns         = module.security.kms_key_arns
  iam_role_names       = module.security.iam_role_names
  tags                 = local.common_tags
}
