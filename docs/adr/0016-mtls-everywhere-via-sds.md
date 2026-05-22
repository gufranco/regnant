# ADR-0016: mTLS between every service via SDS

**Status:** accepted
**Date:** 2026-05-22

## Context

Zero-trust between mesh services is the 2026 baseline. The original
platform relied on network-layer trust plus auth at the edge; this
project takes the stricter posture.

## Decision

- A local root CA created by `tls_self_signed_cert` in the security
  module.
- Per-service leaf certificates derived from the root, bundled with
  the leaf private key and CA certificate, stored as
  `regnant/leaf/<service>` in Secrets Manager.
- Sovereign reads every leaf via its `secrets_context` plugin and
  serves them to Envoy through SDS.
- Each service container loads its own bundle on boot via the user-data
  script (AMI) or a Docker entrypoint helper (runtime image).
- Envoy listeners enforce client certificate verification on the L4
  inbound; clusters present mTLS upstream.

## Alternatives Considered

### SPIFFE/SPIRE

Pros: identity is decoupled from transport material; workload identity
is verifiable.
Cons: significant operational surface (server, agent, attestor) for a
local-first project.

### Plaintext inside the VPC

Pros: simplest.
Cons: violates the zero-trust posture; loses the SDS demonstration.

## Consequences

### Positive

- Lateral movement inside the VPC requires a cert; a compromised
  backend cannot reach Sovereign without one.
- Cert rotation is one Terraform apply.

### Negative

- Boot sequence ordering: Secrets Manager must be ready before any
  service starts.

### Risks

- Rotation breaks long-lived connections briefly. Mitigation: SDS
  pushes new material without restart; runbook documents the rotation
  procedure.
