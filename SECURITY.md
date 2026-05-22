# Security Policy

## Reporting a Vulnerability

If you discover a security issue in `regnant`, do **not** open a public GitHub issue. Email the maintainer privately at the address in `CODEOWNERS`, or use GitHub's private vulnerability reporting at https://github.com/gufranco/regnant/security/advisories/new.

You should receive a response within 72 hours. We will work with you to confirm the issue, plan a fix, and coordinate disclosure.

## Scope

This project is a local-development reproduction of an internet-facing platform. It is **not** intended for production use as-is. The following are explicitly out of scope:

- Hard-coded demo credentials in `identity/keycloak/realm-export.json`.
- The local self-signed CA in `security/ca/` (production deployments must use a managed CA or ACM).
- The `regnant-cli` storing OIDC refresh tokens in the OS keychain (intended; documented).
- LocalStack itself; report LocalStack bugs upstream.

## In scope

- Privilege escalation paths inside the running containers.
- Container escape from the Envoy fleet image.
- mTLS bypass between mesh services.
- Anything that allows an unauthenticated request to reach a backend.
- Supply-chain attacks against our build pipeline.

## Disclosure

We follow Coordinated Vulnerability Disclosure. After a fix is shipped and a reasonable upgrade window has passed, the advisory is published with credit to the reporter.

## Supply chain

Every release ships with:

- A Sigstore Cosign signature on every container image.
- An SPDX SBOM via Syft.
- A Trivy scan report.
- SLSA Level 2 provenance.

Verify a release artifact:

```bash
cosign verify ghcr.io/gufranco/regnant/<image>:<tag> \
  --certificate-identity-regexp '^https://github\.com/gufranco/regnant/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
