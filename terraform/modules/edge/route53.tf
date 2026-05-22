# Private hosted zone for the regnant domain. Records alias to the
# CloudFront distribution at the apex and to the NLB directly for
# internal subdomains.

resource "aws_route53_zone" "main" {
  name = var.domain_name

  vpc {
    vpc_id = var.vpc_id
  }

  tags = merge(local.module_tags, {
    Name = "${var.name_prefix}-zone"
  })
}

resource "aws_route53_record" "apex_alias" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.edge.domain_name
    zone_id                = aws_cloudfront_distribution.edge.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "subdomain_alias" {
  for_each = toset(var.subdomains)

  zone_id = aws_route53_zone.main.zone_id
  name    = "${each.key}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.edge.domain_name
    zone_id                = aws_cloudfront_distribution.edge.hosted_zone_id
    evaluate_target_health = false
  }
}

# Direct alias to the NLB for internal callers (e.g., service-to-service
# tests that want to bypass CloudFront).
resource "aws_route53_record" "nlb_direct" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "internal.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.nlb_dns_name
    zone_id                = var.nlb_zone_id
    evaluate_target_health = true
  }
}
