# Outputs surfaced after `tofu apply`.
# Filled out as modules come online in later phases.

output "region" {
  description = "Synthetic region label used everywhere."
  value       = var.region_label
}

output "localstack_endpoint" {
  description = "Base URL where LocalStack is reachable."
  value       = var.localstack_endpoint
}

output "osb_api_url" {
  description = "Open Service Broker API base URL."
  value       = "http://localhost:8080"
}

output "sovereign_url" {
  description = "Sovereign XDS HTTP endpoint."
  value       = "http://localhost:8000"
}

output "envoy_admin_urls" {
  description = "Per-instance Envoy admin endpoints (localhost-only)."
  value = [
    for i in range(1, var.envoy_instance_count + 1) :
    "http://localhost:${9900 + i}"
  ]
}

output "grafana_url" {
  description = "Grafana UI."
  value       = "http://localhost:3000"
}

output "keycloak_url" {
  description = "Keycloak admin and OIDC issuer."
  value       = var.keycloak_url
}

output "prometheus_url" {
  description = "Prometheus UI."
  value       = "http://localhost:9090"
}

output "loki_url" {
  description = "Loki HTTP endpoint."
  value       = "http://localhost:3100"
}

output "tempo_url" {
  description = "Tempo HTTP endpoint."
  value       = "http://localhost:3200"
}

output "vpc_id" {
  description = "VPC identifier from the network module."
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet ids from the network module."
  value       = module.network.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet ids from the network module."
  value       = module.network.public_subnet_ids
}

output "kms_key_arns" {
  description = "KMS key ARNs keyed by purpose."
  value       = module.security.kms_key_arns
}

output "iam_role_arns" {
  description = "Service IAM role ARNs keyed by service."
  value       = module.security.iam_role_arns
}

output "security_group_ids" {
  description = "Security group ids keyed by tier."
  value       = module.security.security_group_ids
}

output "acm_certificate_arn" {
  description = "ACM certificate for the public edge."
  value       = module.security.acm_certificate_arn
}

output "leaf_secret_arns" {
  description = "Per-service mTLS leaf bundle ARNs."
  value       = module.security.leaf_secret_arns
}

output "osb_artifact_bucket" {
  description = "S3 bucket holding OSB provisioning artifacts."
  value       = module.osb.artifact_bucket_name
}

output "osb_instances_table" {
  description = "DynamoDB table for service instances."
  value       = module.osb.instances_table_name
}

output "osb_bindings_table" {
  description = "DynamoDB table for service bindings."
  value       = module.osb.bindings_table_name
}

output "osb_provision_queue_url" {
  description = "SQS URL for provisioning tasks."
  value       = module.osb.provision_queue_url
}

output "osb_binding_queue_url" {
  description = "SQS URL for binding tasks."
  value       = module.osb.binding_queue_url
}

output "envoy_nlb_dns" {
  description = "DNS name of the Envoy fleet's network load balancer."
  value       = module.envoy_fleet.nlb_dns_name
}

output "envoy_autoscaling_group" {
  description = "Envoy fleet autoscaling group name."
  value       = module.envoy_fleet.autoscaling_group_name
}

output "envoy_target_group_arn" {
  description = "Envoy NLB target group ARN."
  value       = module.envoy_fleet.target_group_arn
}

output "envoy_ami_id" {
  description = "AMI id the fleet launch template references."
  value       = module.envoy_fleet.ami_id
}

output "edge_public_url" {
  description = "Primary URL where the platform is reachable."
  value       = module.edge.public_url
}

output "edge_internal_url" {
  description = "Internal URL that bypasses CloudFront."
  value       = module.edge.internal_url
}

output "edge_cloudfront_domain" {
  description = "CloudFront-managed domain name."
  value       = module.edge.cloudfront_domain_name
}

output "edge_hosted_zone_id" {
  description = "Route53 hosted zone id."
  value       = module.edge.hosted_zone_id
}

output "observability_archive_bucket" {
  description = "S3 bucket for long-term log and trace archival."
  value       = module.observability.archive_bucket_name
}

output "observability_log_groups" {
  description = "CloudWatch log group names keyed by service."
  value       = module.observability.log_group_names
}
