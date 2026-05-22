# ADR-0007: Auth sidecar in Rust, ratelimit via Steward

**Status:** accepted
**Date:** 2026-05-22

## Context

The canvas shows the Envoy fleet enforcing four cross-cutting concerns:
authentication, authorization, rate limiting, and access logs. Each
needs an enforcement point.

## Decision

- **Authentication + authorization**: a Rust gRPC sidecar implementing
  Envoy's `ext_authz` service. Validates JWTs against Keycloak via
  JWKS. Propagates user identity and roles into the filter chain via
  `x-regnant-*` headers.
- **Rate limiting**: the upstream Lyft ratelimit implementation
  rewritten in Rust (`cetanu/steward`). Backed by Redis. Domain
  descriptors are per-product (jira/confluence/bitbucket) and per-tier
  (free/pro/enterprise).
- **Access logs**: Envoy's `envoy.access_loggers.open_telemetry`
  emits to the OTel Collector via OTLP gRPC.

## Alternatives Considered

### ext_authz inside Envoy via WASM

Pros: zero out-of-process latency.
Cons: WASM modules can't make outbound HTTPS calls reliably; JWKS
caching becomes hard.

### Lyft ratelimit reference (Go)

Pros: official Envoy partner.
Cons: replaces an opportunity to use a code path the original platform
author already authored.

## Consequences

### Positive

- Each concern lives in its own process with its own SLOs.
- Operators can swap any of them without touching Envoy config.

### Negative

- Three extra containers in the local stack.

### Risks

- Sidecar latency dominates the request budget. Mitigation: pin both
  sidecars to the same host as Envoy in production; locally they share
  the docker bridge.
