# ADR-0005: Use upstream Sovereign rather than reimplement the control plane

**Status:** accepted
**Date:** 2026-05-22

## Context

The Envoy XDS control plane this project needs already exists, written
by the same engineer who designed the original Atlassian platform.

## Decision

Pull `sovereign` from PyPI, ship a Dockerfile that copies our config
and templates into the canonical install path, and write two custom
context plugins for AWS Secrets Manager and the OSB artifact bucket.

## Alternatives Considered

### Build a control plane in-house

Pros: avoids any upstream limitations.
Cons: large surface area, drift from the canonical implementation,
high maintenance cost.

### Use go-control-plane

Pros: official Envoy reference implementation.
Cons: lower level, would need its own templating layer; loses the
faithfulness to the source material.

## Consequences

### Positive

- Two-line config plus a couple of plugins gets us a working XDS plane.
- Upstream fixes and features flow to us for free.

### Negative

- Bound to upstream's release cadence and design choices.
- Python runtime overhead vs a Go implementation.

### Risks

- Upstream Sovereign goes unmaintained. Mitigation: the code is Apache
  2.0; we could fork at any point.
