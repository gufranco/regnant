output "ami_id" {
  description = "AMI id resolved from the Packer build, or the fallback."
  value       = local.resolved_ami_id
}

output "launch_template_id" {
  description = "Launch template id."
  value       = aws_launch_template.envoy.id
}

output "launch_template_latest_version" {
  description = "Latest launch template version."
  value       = aws_launch_template.envoy.latest_version
}

output "autoscaling_group_name" {
  description = "ASG name."
  value       = aws_autoscaling_group.envoy.name
}

output "autoscaling_group_arn" {
  description = "ASG ARN."
  value       = aws_autoscaling_group.envoy.arn
}

output "instance_profile_name" {
  description = "Instance profile attached to fleet instances."
  value       = aws_iam_instance_profile.envoy.name
}

output "nlb_arn" {
  description = "Network Load Balancer ARN."
  value       = aws_lb.envoy.arn
}

output "nlb_dns_name" {
  description = "DNS name the NLB resolves to."
  value       = aws_lb.envoy.dns_name
}

output "nlb_zone_id" {
  description = "Hosted zone id for the NLB (for Route53 alias records)."
  value       = aws_lb.envoy.zone_id
}

output "target_group_arn" {
  description = "Target group attached to the ASG."
  value       = aws_lb_target_group.envoy.arn
}

output "instance_count" {
  description = "Desired Envoy instance count."
  value       = var.envoy_instance_count
}
