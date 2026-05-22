# ADR-0015: Supply chain: cosign, SBOM, Trivy, SLSA

**Status:** accepted
**Date:** 2026-05-22

## Context

Every container image needs provenance, a bill of materials, and a
clean vulnerability profile before it ships.

## Decision

- **Sign**: every image is signed with `sigstore/cosign` using
  keyless OIDC in CI. A local keypair sits under
  `security/cosign/` for offline builds.
- **SBOM**: `syft` produces SPDX-JSON per image. Attached to GitHub
  release artifacts.
- **Scan**: `trivy image --severity HIGH,CRITICAL --exit-code 1`. CI
  fails on findings.
- **SLSA**: Level 2 provenance via `slsa-github-generator` attached
  to releases.

Per-language audit tools run in `lint.yml`: `cargo-deny` for Rust,
`pip-audit` for Python, `govulncheck` for Go.

Dependency updates: Renovate (primary), Dependabot (fallback for
GitHub Actions and security alerts).

## Alternatives Considered

### Skip signing, rely on registry checksums

Pros: simpler.
Cons: no provenance binding to source.

### Snyk or other commercial scanner

Pros: prettier dashboards.
Cons: paid, vendor lock-in.

## Consequences

### Positive

- Every artifact is auditable from `cosign verify` plus the SBOM and
  the SLSA attestation.
- HIGH/CRITICAL CVEs cannot land on `main` undetected.

### Negative

- Daily Trivy scans add CI minutes.
- A new CVE in a baseline image can block all releases.

### Risks

- Sigstore's transparency log goes down. Mitigation: signatures are
  stored alongside images so verification still works against the
  cached log.
