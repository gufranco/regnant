# ADR-0006: Packer with a Docker source plus a runtime mirror image

**Status:** accepted
**Date:** 2026-05-22

## Context

LocalStack's mock EC2 does not boot AMIs. The platform we are
reproducing is documented as Packer + Salt baking an AMI launched by an
AutoScaling Group. Faithfulness requires keeping that pipeline; the
local stack also needs an actual running Envoy.

## Decision

Two artifacts from the same Salt tree:

- **Packer (docker source)**: applies the Salt highstate in a
  debian:12-slim container and commits the result. A shell-local
  post-processor registers a synthetic AMI in the LocalStack EC2
  catalog so the `aws_ami_ids` data lookup in the envoy-fleet module
  resolves.
- **Docker (mirror)**: `ami/docker/Dockerfile` builds a distroless
  runtime image with the same Envoy binary, OTel agent, and bootstrap
  template. docker-compose Envoy services run this image.

The two artifacts are byte-equivalent for the parts the data plane
touches at runtime.

## Alternatives Considered

### Skip the AMI build entirely

Pros: less code.
Cons: the canvas's region 4 disappears. Loses the auditable
Packer + Salt structure that production would use on real AWS.

### Build a real AMI against real AWS

Pros: closes the loop completely.
Cons: requires AWS credentials and money for a learning project.

## Consequences

### Positive

- Same Salt tree drives local and production behavior.
- The AMI build pipeline is exercised on every push.

### Negative

- Two Dockerfiles to keep in sync.
- The synthetic AMI id LocalStack stores is not a real boot image.

### Risks

- The two artifacts drift. Mitigation: a CI check verifies that the
  Docker mirror image starts cleanly and the AMI build completes.
