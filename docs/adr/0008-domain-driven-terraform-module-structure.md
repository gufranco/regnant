# ADR-0008: Domain-driven Terraform module structure

**Status:** accepted
**Date:** 2026-05-22

## Context

The canvas decomposes the platform into seven logical regions plus a
small set of cross-cutting concerns. Module boundaries can mirror that
decomposition or follow AWS-service boundaries.

## Decision

One Terraform module per canvas region: `network`, `security`, `osb`,
`sovereign`, `envoy-fleet`, `edge`, `observability`, plus an `identity`
module for Keycloak. The env composition layer
(`terraform/envs/local/main.tf`) wires them together.

Each module owns its inputs, outputs, README, and `versions.tf`.

## Alternatives Considered

### Flat: one big terraform/main.tf

Pros: simplest navigation.
Cons: violates the "deep modules" principle. Every change touches the
same file. State becomes harder to reason about.

### By AWS service (one module per service)

Pros: matches AWS docs.
Cons: cross-cutting concerns scatter across many modules; a single
canvas region (e.g., OSB) spans multiple services.

## Consequences

### Positive

- A canvas reader can find the matching module from the diagram name.
- Module READMEs cross-link back to the diagram.
- Easy to disable a region for a focused test by commenting one block.

### Negative

- More files; eight module directories.

### Risks

- Cross-module references can become tangled. Mitigation: the env
  composition layer is the only place modules learn about each other.
