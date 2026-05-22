# Scaling regnant

The default local environment runs three Envoy instances in a single
synthetic region. Production at the source-material scale was ~2000
proxies across 13 AWS regions. Same Terraform code; only the variables
change.

## Knobs that scale

| Variable | Default | Production-class value |
|----------|---------|------------------------|
| `envoy_instance_count` | `3` | per-region capacity, typically 100-200 |
| `region_label` | `us-east-1` | one apply per real region |
| `vpc_cidr` | `10.42.0.0/16` | distinct CIDR per region to avoid overlap |
| `public_subnet_cidrs` | three `/20`s | a /20 per AZ; at 2000 proxies allow `/22` |
| `private_subnet_cidrs` | three `/20`s | match public layout |
| `instance_type` | `c7i.large` | `c7i.4xlarge` or larger for sustained throughput |

The launch template, ASG, NLB, target group, security groups, IAM
roles, and KMS keys are identical at any count.

## Multi-region

The local environment is single-region. For a 13-region deployment:

1. Stand up one Terraform root per region under `terraform/envs/<region>/`,
   each composing the same modules with a different `region_label` and
   a non-overlapping `vpc_cidr`.
2. Federate the OSB by either pinning a single API in one region and
   accepting cross-region latency, or by running an OSB API per region
   with a shared DynamoDB Global Table.
3. The Sovereign control plane scales horizontally; deploy a Sovereign
   per region, each reading the local S3 artifact bucket.
4. The Envoy fleets register with their local Sovereign and serve the
   local edge tier.

## Per-region capacity math

At ~150 instances per region and 13 regions, you reach the
1950-instance neighborhood the source material describes. A
`c7i.large` Envoy can sustain low five-figure RPS at sub-millisecond
overhead with the AMI's network tuning enabled (BBR congestion
control, hugepages, NUMA bind, IRQ pinning); larger instance types
scale linearly until you saturate the NIC.

## Cost notes (real AWS, not LocalStack)

A single-region deployment at 150 `c7i.large` instances with cross-AZ
NLB, KMS rotation enabled, and CloudFront in front runs about
$45,000/month list. 13 regions at the same shape land around
$580,000/month before reserved-instance discounts.

## What does not scale by changing a variable

- The control plane (Sovereign) is one process per region. To shard,
  use the `matched_service` selector to bind Envoys to specific
  Sovereign instances.
- The OSB Worker is a single asyncio loop per replica. For high
  provisioning throughput, run multiple replicas behind the same SQS
  queue (queue redelivery semantics already handle the contention).
- The auth sidecar caches JWKS for five minutes; pushing past
  ~10k req/s per sidecar requires more replicas in front of Envoy.
