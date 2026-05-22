# ADR-0002: LocalStack Community plus an nginx CloudFront surrogate

**Status:** accepted
**Date:** 2026-05-22

## Context

LocalStack Community covers most of the AWS API surface this project
uses (S3, SQS, DynamoDB, EC2, IAM, Route53, KMS, ACM email validation).
CloudFront on Community returns the right shape from the API but does
not run real cache behavior, custom-headers logic, or origin-policy
enforcement. LocalStack Pro fixes this but costs per-developer-seat
and gates contribution.

## Decision

Target LocalStack 4.x Community. For features Community implements
partially:

- **CloudFront**: ship an nginx container in docker-compose that
  fronts the Envoy NLB, terminates TLS, sets the security-headers
  policy CloudFront would, and forwards everything to the upstream.
  Terraform still declares the `aws_cloudfront_distribution` so the
  resource graph matches production.
- **ACM**: use `validation_method = "EMAIL"`. LocalStack auto-approves
  on certificate creation.

## Alternatives Considered

### LocalStack Pro

Pros: closer parity to real AWS for CloudFront, ECS, RDS Aurora.
Cons: paid; contributors without a seat cannot reproduce.

### Skip CloudFront in local

Pros: simplest compose graph.
Cons: drops a region of the canvas; the platform's behavior at the
edge becomes invisible locally.

## Consequences

### Positive

- Free.
- The nginx surrogate is mature and well-understood.

### Negative

- The headers and TLS behavior must be kept in sync across two places
  (nginx config + Terraform CloudFront definition).

### Risks

- Cache misses behave differently between nginx and real CloudFront.
  Mitigation: do not rely on cache semantics in local tests; the load
  test suite hits the NLB directly for that reason.
