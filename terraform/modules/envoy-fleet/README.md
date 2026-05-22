# Envoy fleet module

Provisions the Envoy data plane on EC2: launch template, autoscaling
group, network load balancer, and the supporting instance profile.
The runtime data plane in docker-compose mirrors what these resources
declare so the behavior matches end-to-end.

## Components

### Launch template

Resolves the AMI by name pattern via `aws_ami_ids`. When the Packer
pipeline has not run yet, falls back to a placeholder id so the first
`tofu apply` does not fail.

Boots with:

- IMDSv2 required (`http_tokens = "required"`)
- Detailed monitoring
- gp3 root volume, 20 GB, KMS-encrypted with the security module's S3 key
- User-data shipped via `user-data.sh.tmpl` that pulls the mTLS leaf
  bundle and CA cert from Secrets Manager, writes them to
  `/etc/envoy/tls/`, and starts the Envoy + OTel Collector systemd
  units that the AMI ships

### Autoscaling group

`min_size = desired_capacity = var.envoy_instance_count`; `max_size`
is 2x to allow rolling refreshes without dropping below desired
capacity. Health check type is `ELB` so unhealthy instances rotate
when the target group fails them. `instance_refresh` is configured
with a 66 percent minimum healthy and a 30 second warmup.

### NLB

Internet-facing network load balancer. TCP 443 listener forwards to
a TCP 10000 target group. Health check polls `/ready` on port 9901
(Envoy admin) over HTTP and expects a 2xx. Cross-zone load balancing
enabled.

## Inputs

| Name                      | Description                                 | Type           | Default                      |
| ------------------------- | ------------------------------------------- | -------------- | ---------------------------- |
| `name_prefix`             | Prefix on every named resource              | `string`       | required                     |
| `region_label`            | Region label, for tags and user-data        | `string`       | required                     |
| `vpc_id`                  | VPC id from the network module              | `string`       | required                     |
| `subnet_ids`              | Subnets for the ASG and NLB                 | `list(string)` | required                     |
| `envoy_instance_count`    | Desired instance count                      | `number`       | `3`                          |
| `instance_type`           | EC2 instance type                           | `string`       | `c7i.large`                  |
| `ami_owner`               | AMI owner filter                            | `string`       | `self`                       |
| `ami_name_pattern`        | AMI name pattern from Packer                | `string`       | `regnant-envoy-*`            |
| `fallback_ami_id`         | Used when no Packer image is registered yet | `string`       | `ami-12345678`               |
| `key_pair_name`           | Key pair from the security module           | `string`       | required                     |
| `envoy_security_group_id` | SG id from the security module              | `string`       | required                     |
| `envoy_iam_role_name`     | IAM role name from the security module      | `string`       | required                     |
| `leaf_secret_arn`         | Envoy mTLS leaf bundle ARN                  | `string`       | required                     |
| `ca_secret_arns`          | CA secret ARN map                           | `map(string)`  | required                     |
| `kms_key_arns`            | KMS ARN map                                 | `map(string)`  | required                     |
| `sovereign_xds_endpoint`  | XDS endpoint URL                            | `string`       | `sovereign:8080`             |
| `otel_collector_endpoint` | OTLP endpoint                               | `string`       | `http://otel-collector:4317` |
| `tags`                    | Tags merged into every resource             | `map(string)`  | `{}`                         |

## Outputs

`ami_id`, `launch_template_id`, `launch_template_latest_version`,
`autoscaling_group_name`, `autoscaling_group_arn`,
`instance_profile_name`, `nlb_arn`, `nlb_dns_name`, `nlb_zone_id`,
`target_group_arn`, `instance_count`.

## Notes

- The fleet's actual data-plane work happens in docker-compose; the
  EC2 ASG entries in LocalStack are catalog entries that document
  what production would create. The Packer pipeline registers an AMI
  in the LocalStack EC2 catalog so the data lookup resolves.
- Cross-module dependency: the envoy IAM role must exist in the
  security module's `iam_role_names` map under the `envoy` key.
