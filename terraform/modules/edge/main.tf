locals {
  module_tags = merge(var.tags, {
    "regnant.module" = "edge"
  })

  apex_fqdn      = var.domain_name
  edge_origin_id = "${var.name_prefix}-nlb-origin"
}
