# ADR-0010: Three product-flavored backend services

**Status:** accepted
**Date:** 2026-05-22

## Context

The canvas's four anonymous backend boxes are not informative. The
videos name the products this platform fronts: Jira, Confluence, and
Bitbucket.

## Decision

Three backend services, each with a distinct API surface:
- `backend-jira-clone`: issues, projects, sprints
- `backend-confluence-clone`: pages, spaces, labels
- `backend-bitbucket-clone`: repos, pull requests, branches

Naming uses the `-clone` suffix; trademarks are not used in service
identifiers or UI; README adds a disclaimer.

## Alternatives Considered

### Three anonymous backends

Pros: zero trademark exposure.
Cons: routing rules, ratelimit policies, and access logs become
indistinguishable; dashboards can't tell the products apart.

### One backend serving all three product paths

Pros: simpler.
Cons: the platform's multi-tenant routing story disappears.

## Consequences

### Positive

- The three backends route differently through Envoy and accumulate
  different ratelimit counters; Grafana dashboards show real per-product
  splits.

### Negative

- Three Dockerfiles, three FastAPI apps, three sets of tests.

### Risks

- Reads like a trademark grab. Mitigation: explicit disclaimer in
  README and per-service file headers.
