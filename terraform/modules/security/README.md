# Security module

Owns every cryptographic and authorization primitive the platform
relies on: customer-managed KMS keys, the local root certificate
authority that backs mTLS between mesh services, IAM roles per
service, the ACM certificate the public edge presents, and the
security group set.

## Components

### KMS

Five customer-managed keys, all with automatic rotation enabled and a
seven-day deletion window. Each key has an alias for stable reference.

| Purpose | Used by |
|---------|---------|
| `s3` | OSB artifact bucket, observability archive bucket |
| `dynamodb` | `service_instances` and `service_bindings` tables |
| `sqs` | `provision-tasks` and `binding-tasks` queues |
| `secrets` | Envelope encryption for every Secrets Manager entry |
| `logs` | CloudWatch log group encryption |

### Local CA + mTLS leaf certificates

`tls_self_signed_cert` produces a P-256 root certificate, valid for
`var.tls_validity_hours`. For every entry in `var.mesh_services` the
module mints a leaf certificate signed by the root, packs it into a
JSON bundle alongside its private key and the CA public cert, and
stores it in Secrets Manager under `regnant/leaf/<service>`. Sovereign
reads these bundles and serves them to Envoy via SDS.

The root CA's public certificate is also stored in Secrets Manager
under `regnant/ca/cert`; containers fetch it at boot to populate their
trust store.

### IAM

A single permission boundary caps every mesh role to: observability
APIs, KMS decrypt + GenerateDataKey, Secrets Manager read on the
`regnant/*` prefix, S3/DynamoDB/SQS scoped by the `project=regnant`
resource tag. Explicit deny on any `iam:*` action and on KMS key
administration.

Each service gets a role with the boundary attached, the observability
baseline policy, and a policy granting read access to its own leaf
bundle. Sovereign gets an extra policy granting read access to every
leaf bundle in the prefix.

Downstream modules attach their own inline policies for the specific
S3 bucket, DynamoDB table, and SQS queue they create.

### ACM

A single email-validated certificate for `var.domain_name` plus the
wildcard SAN. LocalStack auto-approves the validation. Production
deployments switch the validation method to DNS via the Route53 zone
the edge module creates.

### EC2 key pair

A 4096-bit RSA key. The public half registers as `aws_key_pair`
`regnant-fleet`; the private half lives in Secrets Manager.

### Security groups

Four groups: `envoy`, `osb-api`, `sovereign`, `redis`. Ingress rules
are narrow (specific ports from the VPC CIDR or from the public
internet for the edge listener). Egress is broad in local dev; a
production variant would scope it to known upstream CIDRs.

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `name_prefix` | Prefix on every named resource | `string` | required |
| `region_label` | Region label, used in CA subject and tags | `string` | required |
| `vpc_id` | VPC id from the network module | `string` | required |
| `vpc_cidr` | VPC CIDR for in-VPC ingress rules | `string` | required |
| `domain_name` | Public-facing domain | `string` | required |
| `tls_validity_hours` | Validity for CA and leaves | `number` | `8760` |
| `mesh_services` | Services needing a role + leaf cert | `list(string)` | nine entries, see `variables.tf` |
| `tags` | Tags merged into every resource | `map(string)` | `{}` |

## Outputs

`kms_key_arns`, `kms_key_ids`, `kms_alias_names`, `iam_role_arns`,
`iam_role_names`, `permission_boundary_arn`, `ca_cert_pem`,
`ca_secret_arns`, `leaf_secret_arns`, `acm_certificate_arn`,
`key_pair_name`, `key_pair_secret_arn`, `security_group_ids`.

## Usage

```hcl
module "security" {
  source       = "../../modules/security"
  name_prefix  = "regnant"
  region_label = var.region_label
  vpc_id       = module.network.vpc_id
  vpc_cidr     = module.network.vpc_cidr
  domain_name  = var.domain_name
  tags         = local.common_tags
}
```

## Notes

- The CA in this module is local-only. Browsers will not trust it
  without explicit import. Production deployments should swap the root
  for an organization-managed CA or AWS Private CA.
- Permission boundary uses `aws:ResourceTag` conditions; LocalStack
  honors the tag but does not enforce IAM authorization. Treat the
  policies as documentation of intent rather than runtime enforcement.
- ACM email validation is auto-approved on LocalStack. On real AWS,
  someone has to click the link in the inbox configured for the
  domain's WHOIS contact.
