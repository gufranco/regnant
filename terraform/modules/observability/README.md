# Observability module

AWS-side observability infrastructure: long-term archive bucket and
per-service CloudWatch log groups. The live observability stack
(OpenTelemetry Collector, Prometheus, Grafana, Loki, Tempo, Promtail)
runs in docker-compose; this module sets up the AWS resources those
containers (and any future AWS-native consumers) write to.

## Components

### Archive bucket

Versioned, KMS-encrypted, bucket-enforced ownership, public access
blocked. Lifecycle transitions objects to Infrequent Access after
30 days, Glacier after 90, expiring after 365. Noncurrent versions
expire after 60 days. Incomplete multipart uploads abort after one
day.

### CloudWatch log groups

One log group per service in `var.log_groups` (defaults cover OSB
API/Worker, Sovereign, Envoy, auth sidecar, ratelimit, and the three
backend clones). Each group is KMS-encrypted with the security
module's `logs` key and retains messages for `var.log_retention_days`.

### IAM

Each service role gets an inline policy that:
- Allows `logs:CreateLogStream` and `logs:PutLogEvents` on its own
  log group only
- Allows `kms:Encrypt` and `kms:GenerateDataKey` on the logs KMS key
- Allows `s3:PutObject` on its own prefix in the archive bucket

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `name_prefix` | Resource name prefix | `string` | required |
| `region_label` | Region label, for tags | `string` | required |
| `archive_bucket_name` | Archive bucket name override | `string` | `<prefix>-observability-archive` |
| `kms_key_arns` | KMS ARN map from security | `map(string)` | required |
| `iam_role_names` | Service role names from security | `map(string)` | required |
| `log_retention_days` | CloudWatch retention | `number` | `30` |
| `archive_ia_days` | Days before IA transition | `number` | `30` |
| `archive_glacier_days` | Days before Glacier transition | `number` | `90` |
| `archive_expire_days` | Days before expiration | `number` | `365` |
| `log_groups` | Service names that get a log group | `list(string)` | nine defaults |
| `tags` | Tags merged into every resource | `map(string)` | `{}` |

## Outputs

`archive_bucket_name`, `archive_bucket_arn`, `log_group_names`,
`log_group_arns`.

## Usage

```hcl
module "observability" {
  source         = "../../modules/observability"
  name_prefix    = "regnant"
  region_label   = var.region_label
  kms_key_arns   = module.security.kms_key_arns
  iam_role_names = module.security.iam_role_names
  tags           = local.common_tags
}
```
