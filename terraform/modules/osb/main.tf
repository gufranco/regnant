locals {
  module_tags = merge(var.tags, {
    "regnant.module" = "osb"
  })
}
