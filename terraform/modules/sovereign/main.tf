locals {
  module_tags = merge(var.tags, {
    "regnant.module" = "sovereign"
  })
  ssm_prefix = "/${var.name_prefix}/sovereign"
}
