# Network module

Implements canvas region 3 (the AWS CloudFormation block: VPC, Subnet, IGW).
See [`../../../specs/atlassian-research/diagrams.md`](../../../specs/atlassian-research/diagrams.md) for the source diagram.

Creates a `/16` VPC with three public and three private subnets (one per simulated AZ), an internet gateway, and VPC endpoints for S3, DynamoDB, and SQS. Endpoints keep S3/DynamoDB/SQS traffic on the AWS backbone in production; on LocalStack they are inert but the resource graph matches.

## Inputs

| Name                   | Description                              | Type           | Default                 |
| ---------------------- | ---------------------------------------- | -------------- | ----------------------- |
| `name_prefix`          | Prefix prepended to every named resource | `string`       | required                |
| `region_label`         | Region label used to derive AZ names     | `string`       | required                |
| `vpc_cidr`             | CIDR block for the VPC                   | `string`       | `10.42.0.0/16`          |
| `public_subnet_cidrs`  | CIDRs for the three public subnets       | `list(string)` | three `/20`s in the VPC |
| `private_subnet_cidrs` | CIDRs for the three private subnets      | `list(string)` | three `/20`s in the VPC |
| `enable_vpc_endpoints` | Whether to create VPC endpoints          | `bool`         | `true`                  |
| `tags`                 | Tags merged into every resource          | `map(string)`  | `{}`                    |

## Outputs

`vpc_id`, `vpc_cidr`, `public_subnet_ids`, `private_subnet_ids`, `availability_zones`, `internet_gateway_id`, `public_route_table_id`, `private_route_table_id`, `vpc_endpoint_ids`.

## Usage

```hcl
module "network" {
  source       = "../../modules/network"
  name_prefix  = "regnant"
  region_label = var.region_label
}
```

## Notes

- The subnet CIDR layout reserves the first half of the VPC space for public subnets and the second half for private subnets, leaving room to add more AZs later.
- VPC endpoints for S3 and DynamoDB are gateway type and free. The SQS endpoint is interface type and would cost money on real AWS; controlled via `enable_vpc_endpoints`.
