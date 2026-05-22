# ADR-0009: Full Open Service Broker API v2.16 compliance

**Status:** accepted
**Date:** 2026-05-22

## Context

The OSB API has many endpoints; a learning project could ship a
proper subset and still demonstrate the architecture.

## Decision

Implement the full v2.16 surface: catalog, provision, update,
deprovision, fetch instance, instance last_operation, bind, unbind,
fetch binding, binding last_operation. Asynchronous endpoints accept
`accepts_incomplete=true` as the spec requires.

## Alternatives Considered

### Subset: provision + deprovision + last_operation

Pros: less code.
Cons: bindings are the most interesting part of OSB; skipping them
removes the credential-rotation story.

## Consequences

### Positive

- Compatible with every OSB client (Cloud Foundry, Kubernetes Service
  Catalog, etc.) without modification.

### Negative

- More handlers, more tests.

### Risks

- Subtle spec violations get caught only in cross-platform integration
  tests. Mitigation: the OpenAPI is the single source of truth; the
  SDKs are generated from it.
