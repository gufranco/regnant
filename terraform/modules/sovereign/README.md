# Sovereign module

AWS-side glue for the Sovereign XDS control plane. The runtime container
lives in docker-compose; this module contributes the SSM parameters
Sovereign reads at startup plus the IAM policy giving it read access.

## What it manages

| SSM parameter | Purpose |
|---------------|---------|
| `artifact_bucket` | S3 bucket Sovereign's context plugin scans for Envoy resource YAML |
| `artifact_prefix` | Prefix inside the bucket to scan |
| `redis_url` | Redis URL used for caching and leader election (SecureString) |
| `log_level` | Runtime log verbosity |
| `matched_service` | node.id pattern matched against connecting Envoys |
| `refresh_interval_seconds` | Polling interval for the S3 context source |
| `leaf_secret_arns` | JSON map of service name to leaf bundle ARN |
| `ca_secret_arn` | ARN of the root CA public certificate secret |

The Sovereign role gets an inline policy granting `ssm:GetParameter`
and friends scoped to these specific parameter ARNs, plus
`kms:Decrypt` on the secrets KMS key so the SecureString parameters
resolve.

## Why this shape

Sovereign is upstream Python software; we configure it via env vars
and a YAML config file. Rather than baking the YAML into the container
image, the container's entrypoint reads these SSM parameters and
constructs the YAML on boot. Same image, different parameters, same
runtime behavior across environments.

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `name_prefix` | Resource name prefix | `string` | required |
| `region_label` | Region label, for tags and SSM paths | `string` | required |
| `artifact_bucket_name` | S3 bucket containing XDS context | `string` | required |
| `artifact_prefix` | Prefix inside the bucket | `string` | `envoy-resources/` |
| `leaf_secret_arns` | Service-to-leaf-arn map from security | `map(string)` | required |
| `ca_secret_arns` | CA secret ARN map from security | `map(string)` | required |
| `kms_key_arns` | KMS ARN map from security | `map(string)` | required |
| `iam_role_names` | Service role names from security | `map(string)` | required |
| `redis_url` | Redis connection string | `string` | `redis://redis:6379/0` |
| `log_level` | DEBUG, INFO, WARNING, ERROR | `string` | `INFO` |
| `matched_service` | Envoy node.id pattern | `string` | `envoy-*` |
| `refresh_interval_seconds` | S3 poll interval | `number` | `30` |
| `tags` | Tags merged into every resource | `map(string)` | `{}` |

## Outputs

`ssm_prefix`, `ssm_parameter_arns`, `config_summary`.

## Usage

```hcl
module "sovereign" {
  source               = "../../modules/sovereign"
  name_prefix          = "regnant"
  region_label         = var.region_label
  artifact_bucket_name = module.osb.artifact_bucket_name
  leaf_secret_arns     = module.security.leaf_secret_arns
  ca_secret_arns       = module.security.ca_secret_arns
  kms_key_arns         = module.security.kms_key_arns
  iam_role_names       = module.security.iam_role_names
  tags                 = local.common_tags
}
```

## Notes

- Sovereign's S3 read access is granted by the OSB module, not here,
  because the bucket lives in that module.
- The container handles its own health check and Redis backpressure;
  this module assumes both Redis and the OTel collector are running
  via docker-compose before the container starts.
