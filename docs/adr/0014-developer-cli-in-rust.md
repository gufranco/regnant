# ADR-0014: Developer CLI in Rust

**Status:** accepted
**Date:** 2026-05-22

## Context

Developers consuming the platform need a self-service way to provision
load balancers, bind apps, and inspect status. The OSB API is HTTP, so
any client works; a dedicated CLI gives a discoverable surface.

## Decision

`regnant` CLI in Rust using `clap` v4. Subcommands: `catalog`,
`lb create|list|status|delete|bind|unbind`, `auth login|whoami`.
Output formats: table (default), JSON, YAML. OIDC device-code login
against Keycloak; refresh tokens cached in the OS keychain via
`keyring`.

Distributed as a static binary plus a distroless Docker image.

## Alternatives Considered

### Python click

Pros: lower toolchain barrier.
Cons: heavier runtime; harder to distribute as a single binary.

### Bash + curl

Pros: zero install.
Cons: no typed schemas, no OIDC flow, no token caching, no testable
unit logic.

## Consequences

### Positive

- One install, no Python or Node runtime required on the user's
  machine.
- The Rust SDK shares code with the CLI.

### Negative

- Slower compile times in CI for the matrix of platforms.

### Risks

- The `keyring` crate's macOS implementation prompts the user. On a
  headless CI runner the prompt blocks. Mitigation: device-code login
  is only run interactively; CI uses service-account credentials.
