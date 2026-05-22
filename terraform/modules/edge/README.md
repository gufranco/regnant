# Edge module

The internet-facing boundary: Route53 zone with apex and subdomain
aliases plus a CloudFront distribution that fronts the Envoy NLB.
Adds caching, TLS termination, and a security-headers policy.

## Components

### Route53 hosted zone

Private zone for `var.domain_name` associated to the VPC. Three sets
of records:
- Apex `A`-alias to CloudFront
- Subdomain `A`-aliases for each entry in `var.subdomains`
  (defaults: `api`, `console`, `edge`)
- `internal.<domain>` `A`-alias directly to the NLB so service-to-service
  callers can bypass CloudFront

### CloudFront distribution

Origin is the Envoy NLB over HTTPS. Default cache behavior allows
the full HTTP method set, caches `GET`/`HEAD`, compresses with gzip
and brotli, and forwards `Authorization`, `Accept`, `Accept-Language`,
`Host`, `X-Request-Id`, and `Traceparent` headers as part of the
cache key.

Three policies:
- A cache policy with configurable default and max TTL
- An origin request policy that forwards every cookie, header, and
  query string to the backend
- A response headers policy adding HSTS, X-Content-Type-Options,
  X-Frame-Options DENY, strict-origin-when-cross-origin referrer,
  and XSS protection

Viewer certificate uses the ACM cert from the security module, SNI
only, TLS 1.2 minimum. Geo restriction off. Price class limited to
PriceClass_100 to keep test bills small.

### LocalStack note

LocalStack Community implements CloudFront partially. The nginx
container in docker-compose mirrors the distribution's TLS and
security-headers behavior so the end-to-end stack stays consistent.
Switch to LocalStack Pro or real AWS for full caching behavior.

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `name_prefix` | Resource name prefix | `string` | required |
| `domain_name` | Apex domain | `string` | required |
| `subdomains` | Subdomain aliases | `list(string)` | `["api", "console", "edge"]` |
| `vpc_id` | VPC id for the private zone | `string` | required |
| `nlb_dns_name` | NLB DNS to alias | `string` | required |
| `nlb_zone_id` | NLB hosted zone id | `string` | required |
| `acm_certificate_arn` | ACM cert for the viewer | `string` | required |
| `cache_default_ttl` | Default TTL seconds | `number` | `60` |
| `cache_max_ttl` | Max TTL seconds | `number` | `3600` |
| `tags` | Tags merged into every resource | `map(string)` | `{}` |

## Outputs

`hosted_zone_id`, `hosted_zone_name`, `name_servers`,
`cloudfront_distribution_id`, `cloudfront_domain_name`,
`cloudfront_hosted_zone_id`, `public_url`, `internal_url`.

## Usage

```hcl
module "edge" {
  source              = "../../modules/edge"
  name_prefix         = "regnant"
  domain_name         = var.domain_name
  vpc_id              = module.network.vpc_id
  nlb_dns_name        = module.envoy_fleet.nlb_dns_name
  nlb_zone_id         = module.envoy_fleet.nlb_zone_id
  acm_certificate_arn = module.security.acm_certificate_arn
  tags                = local.common_tags
}
```
