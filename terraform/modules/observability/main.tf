locals {
  module_tags = merge(var.tags, {
    "regnant.module" = "observability"
  })
  archive_bucket = coalesce(var.archive_bucket_name, "${var.name_prefix}-observability-archive")
}
