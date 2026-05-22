# ADR-0012: Keycloak for OIDC

**Status:** accepted
**Date:** 2026-05-22

## Context

The auth sidecar needs an issuer to validate JWTs against. A
hard-coded HS256 secret would work for a learning artifact but not as
a production-shape demo.

## Decision

Run Keycloak 25 as a docker-compose service. Pre-seed a `regnant`
realm with three roles (`viewer`, `editor`, `admin`), three tier groups
(`free-tier`, `pro-tier`, `enterprise-tier`), three backend clients,
one public CLI client with the device-code flow, and three demo users.

The `identity` Terraform module owns the realm declaratively; the
realm-export.json mounted into Keycloak bootstraps the same shape so
the container is functional before `tofu apply` runs.

## Alternatives Considered

### HS256 stub

Pros: simplest.
Cons: not OIDC, no JWKS rotation story, no real auth flow to exercise.

### Auth0 or Cognito

Pros: managed.
Cons: external dependency for a local-first project.

### Authentik / Dex

Pros: lighter than Keycloak.
Cons: smaller community; Keycloak ecosystem is more familiar to most
operators.

## Consequences

### Positive

- The end-to-end OIDC flow works locally: device-code login, token
  refresh, JWKS validation, RBAC by group/role.
- Production swap to Atlassian SSO or any OIDC provider is one config
  change.

### Negative

- ~1 GB of memory dedicated to Keycloak in compose.
- Realm config has two sources (realm-export.json + Terraform); they
  must stay in sync.

### Risks

- Realm drift between Terraform and the imported export. Mitigation: a
  CI job runs a round-trip check.
