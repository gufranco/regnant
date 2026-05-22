# Public-facing ACM certificate for CloudFront / NLB. LocalStack
# auto-approves email validation; production switches to DNS.

resource "aws_acm_certificate" "edge" {
  domain_name       = var.domain_name
  validation_method = "EMAIL"

  subject_alternative_names = [
    "*.${var.domain_name}",
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.module_tags, {
    Name = "${var.name_prefix}-edge-cert"
  })
}
