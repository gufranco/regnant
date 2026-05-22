# ADR-0017: Distroless, non-root, read-only container baseline

**Status:** accepted
**Date:** 2026-05-22

## Context

Every CIS Docker Benchmark control we can adopt cheaply moves the
baseline; the difference between a distroless image and a debian one
is several MB of attack surface that costs nothing to remove.

## Decision

Every regnant image follows the same recipe:

- Multi-stage Dockerfile: builder on `*-slim-bookworm` or `rust:*`,
  final stage on `gcr.io/distroless/*:nonroot` or
  `cgr.dev/chainguard/*`.
- `USER nonroot` (UID >= 10000) in the final stage.
- No shell, no package manager in the final image.
- Multi-arch via `docker buildx`: `linux/amd64` and `linux/arm64`.
- Hadolint clean on every Dockerfile; CI enforces.

In compose:

- `security_opt: [no-new-privileges:true]`
- `cap_drop: [ALL]`; explicit `cap_add` only where required
- `read_only: true` with `tmpfs:` mounts for ephemeral writes
- Memory and CPU limits on every service
- Healthcheck + `restart: unless-stopped`

## Alternatives Considered

### Alpine bases

Pros: small.
Cons: musl libc surprises (DNS, getaddrinfo) and a busier attack
surface than distroless.

### Run as root, allow shells, set no caps

Pros: easier debugging.
Cons: violates every CIS control; not what production looks like.

## Consequences

### Positive

- Tiny final images (50-100 MB each).
- Trivy's HIGH/CRITICAL gate is easier to keep clean.
- Containers crash hard if they try to write where they shouldn't,
  forcing developers to declare tmpfs paths.

### Negative

- Debugging requires `docker debug` or a sidecar image.
- Multi-arch builds take longer in CI.

### Risks

- A library expects a `/tmp` that's not declared. Mitigation: every
  Dockerfile declares a tmpfs for `/tmp` and `/var/run`.
