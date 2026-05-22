# ADR-0003: Configurable Envoy scale, default of three

**Status:** accepted
**Date:** 2026-05-22

## Context

Production at Atlassian ran ~2000 Envoy proxies across 13 AWS regions.
A laptop cannot run 2000 containers, and 13 LocalStack instances are
overkill for a learning artifact.

## Decision

Expose `envoy_instance_count` (default 3) and `region_label` (default
`us-east-1`) as Terraform variables. The Terraform code is structurally
identical to what a 2000/13 deployment would produce; only the variable
values differ. `docs/SCALE.md` documents the math.

## Alternatives Considered

### Multiple LocalStack instances per region

Pros: more faithful to the multi-region story.
Cons: 13x resource footprint, slow boot.

### Hard-coded count of 2000

Pros: nominal faithfulness.
Cons: unrunnable. Defeats the purpose.

## Consequences

### Positive

- Same code path between local dev and the production-sized variant.

### Negative

- No way to exercise cross-region failover locally.

### Risks

- Code paths that depend on instance count (sharding, leader election)
  might behave differently at 3 vs 2000. Mitigation: load-test with a
  realistic ratio of clients to instances.
