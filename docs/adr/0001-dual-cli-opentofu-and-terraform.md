# ADR-0001: Dual-CLI support for OpenTofu and Terraform

**Status:** accepted
**Date:** 2026-05-22

## Context

OpenTofu forked from Terraform 1.5 after HashiCorp moved Terraform 1.6+
to the Business Source License. Both CLIs accept the same HCL surface
the project uses; many readers will already have one installed and not
the other.

## Decision

Write HCL that validates and applies under both CLIs. CI runs the
matrix on both. The default in shipped scripts is `tofu`, with a
graceful fall-back to `terraform` when only the latter is on `PATH`.

## Alternatives Considered

### OpenTofu only

Pros: smaller test surface, no exposure to BSL terms.
Cons: contributors on Terraform get a friction-point.

### Terraform only

Pros: largest tutorial corpus and stack-overflow hits.
Cons: BSL license tightening over time; community fragmentation.

## Consequences

### Positive

- Lower friction for first-time runners.
- License optionality preserved.

### Negative

- CI matrix doubles for IaC validation jobs.

### Risks

- A future provider release could rely on an OpenTofu-only feature.
  Mitigation: pin providers and run both CLIs in CI on every push.
