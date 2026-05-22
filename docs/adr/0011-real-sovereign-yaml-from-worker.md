# ADR-0011: Worker emits real Sovereign-shaped YAML

**Status:** accepted
**Date:** 2026-05-22

## Context

The canvas draws an arrow from the OSB Worker's S3 artifact bucket to
Sovereign's context source. A learning artifact could emit a JSON
placeholder and call it done.

## Decision

The OSB Worker renders per-instance YAML matching Envoy's
data-plane-api field names: `clusters`, `routes`, `listeners`,
`secrets`, `extension_configs`. Sovereign's S3 context plugin reads
these documents and templates render them into XDS responses.

## Alternatives Considered

### JSON stub

Pros: trivial to author.
Cons: the arrow on the canvas becomes a lie; the end-to-end flow does
not actually configure anything.

## Consequences

### Positive

- The OSB-to-Envoy loop closes end-to-end at runtime.
- Tests can assert that a `regnant lb create` call leads to Envoy
  routing real traffic.

### Negative

- The Worker has to encode every Envoy field name correctly.
- Schema drift between Envoy releases requires worker updates.

### Risks

- Hand-coded YAML drifts from the protobuf. Mitigation: use the
  upstream `envoy_data_plane` typed Python bindings to validate output
  in tests.
