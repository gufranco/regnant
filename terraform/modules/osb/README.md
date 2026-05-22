# OSB module

Storage layer for the Open Service Broker: one S3 bucket for
provisioning artifacts, two DynamoDB tables for instance and binding
state, two SQS queues with dead-letter siblings, and inline IAM
policies attaching this module's specific resources to the OSB API,
OSB Worker, and Sovereign roles created by the security module.

## Components

### S3 artifact bucket

A versioned, KMS-encrypted bucket. Bucket policy denies plaintext
HTTP and rejects uploads that do not use KMS encryption. Lifecycle
expires noncurrent versions after 30 days and aborts incomplete
multipart uploads after 1 day. Object ownership is bucket-enforced so
ACLs cannot grant access.

Sovereign's `s3_context.py` plugin reads YAML artifacts from this
bucket; OSB Workers write to it.

### DynamoDB tables

`service_instances`:
- PK `instance_id`
- GSI `by-state` on the `state` attribute
- TTL on the `ttl` attribute (provisioning tasks can be garbage-collected after a timeout)
- Point-in-time recovery enabled
- KMS-encrypted with the security module's `dynamodb` key

`service_bindings`:
- PK `binding_id`, sort key `instance_id`
- GSI `by-instance` on `instance_id` (list all bindings for an instance)
- Point-in-time recovery enabled
- KMS-encrypted

### SQS queues

Two main queues (`provision-tasks`, `binding-tasks`) and matching DLQs
(`*-dlq`). Redrive policy moves messages to the DLQ after 5 receives.
Visibility timeout is 90 seconds; long-poll wait time is 20 seconds.
All queues are KMS-encrypted with the security module's `sqs` key.
Queue policies grant send-only access to the OSB API role and
receive-only access to the OSB Worker role.

### IAM

Three inline policies attached to roles created by the security
module:
- OSB API: RW on the tables, send on the queues, read on the bucket,
  decrypt/encrypt on the relevant KMS keys
- OSB Worker: RW on the tables, consume on the queues, RW on the
  bucket, decrypt/encrypt on the relevant KMS keys
- Sovereign: read on the bucket, decrypt on the S3 KMS key

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `name_prefix` | Resource name prefix | `string` | required |
| `artifact_bucket_name` | Name of the artifact bucket | `string` | required |
| `kms_key_arns` | KMS ARNs from the security module | `map(string)` | required |
| `iam_role_names` | Service role names from the security module | `map(string)` | required |
| `sqs_visibility_timeout_seconds` | Queue visibility timeout | `number` | `90` |
| `sqs_max_receive_count` | Max receives before DLQ | `number` | `5` |
| `dynamodb_billing_mode` | Table billing mode | `string` | `PAY_PER_REQUEST` |
| `tags` | Tags merged into every resource | `map(string)` | `{}` |

## Outputs

`artifact_bucket_name`, `artifact_bucket_arn`,
`instances_table_name`, `instances_table_arn`,
`bindings_table_name`, `bindings_table_arn`,
`provision_queue_url`, `provision_queue_arn`,
`binding_queue_url`, `binding_queue_arn`,
`provision_dlq_url`, `binding_dlq_url`.

## Usage

```hcl
module "osb" {
  source               = "../../modules/osb"
  name_prefix          = "regnant"
  artifact_bucket_name = var.osb_artifact_bucket_name
  kms_key_arns         = module.security.kms_key_arns
  iam_role_names       = module.security.iam_role_names
  tags                 = local.common_tags
}
```
