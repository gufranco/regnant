locals {
  module_tags = merge(var.tags, {
    "regnant.module" = "envoy-fleet"
  })

  # Resolve the AMI id from the Packer-built image when present; fall
  # back to the placeholder for first-apply scenarios where the AMI
  # pipeline has not run yet.
  resolved_ami_id = length(data.aws_ami_ids.envoy.ids) > 0 ? data.aws_ami_ids.envoy.ids[0] : var.fallback_ami_id
}

data "aws_ami_ids" "envoy" {
  owners = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_name_pattern]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
