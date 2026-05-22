output "hosted_zone_id" {
  description = "Route53 hosted zone id."
  value       = aws_route53_zone.main.zone_id
}

output "hosted_zone_name" {
  description = "Route53 hosted zone name."
  value       = aws_route53_zone.main.name
}

output "name_servers" {
  description = "Authoritative name servers for the zone."
  value       = aws_route53_zone.main.name_servers
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution id."
  value       = aws_cloudfront_distribution.edge.id
}

output "cloudfront_domain_name" {
  description = "CloudFront-managed domain (e.g., d1234.cloudfront.net)."
  value       = aws_cloudfront_distribution.edge.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront's own hosted zone id, for parent alias records."
  value       = aws_cloudfront_distribution.edge.hosted_zone_id
}

output "public_url" {
  description = "Primary URL for the platform."
  value       = "https://${var.domain_name}"
}

output "internal_url" {
  description = "Internal alias bypassing CloudFront."
  value       = "https://internal.${var.domain_name}"
}
