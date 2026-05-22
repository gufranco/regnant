# AMI build pipeline

Builds the Envoy fleet AMI via Packer + SaltStack. The same Salt tree
applies to both the AMI build (real EC2) and the Docker mirror image
(`ami/docker/Dockerfile`) so the byte-level payload stays consistent
across LocalStack and real AWS.

## Pieces

| Path | Purpose |
|------|---------|
| `envoy.pkr.hcl` | Packer template. Two builders: docker (default, applies Salt highstate in a debian:12-slim container and commits the result; also registers a synthetic AMI in LocalStack EC2) and amazon-ebs (commented; production variant) |
| `docker/Dockerfile` | Minimal runtime mirror of the AMI: builder stage downloads envoy + otelcol-contrib; final stage is distroless cc-debian12:nonroot |
| `salt/top.sls` | Highstate orchestrating the five states below |
| `salt/envoy/` | Envoy binary install, bootstrap template, entrypoint, hardened systemd unit |
| `salt/observability/` | OTel collector agent, Vector log forwarder, Node Exporter, agent config that forwards to a central collector |
| `salt/hardening/` | SSH baseline, auditd rules, fail2ban, AppArmor envoy profile, kernel lockdown sysctls, pwquality |
| `salt/network/` | TCP tuning, hugepages, NUMA disable, IRQ pinning, CPU governor performance, GRUB cmdline, ulimits. Maps to the Profit-or-Poverty blog series |
| `salt/containers/` | containerd + runc + crun, default seccomp profile, AppArmor container profile |

## How to build

```bash
scripts/build-ami.sh
```

Required: Docker, AWS CLI (pointed at LocalStack), Packer 1.12+.

Optional environment variables:

| Var | Default | Effect |
|-----|---------|--------|
| `ENVOY_VERSION` | `v1.34.1` | Envoy release line |
| `IMAGE_TAG` | `local` | Tag applied to the committed Docker image and the registered AMI |
| `LOCALSTACK_ENDPOINT` | `http://localhost:4566` | LocalStack endpoint for ec2 register-image |
| `REGION` | `us-east-1` | Region label for the synthetic AMI |

The script runs `packer init`, `packer fmt -check`, `packer validate`,
then `packer build`. The build's docker-tag post-processor commits the
image; the shell-local post-processor calls `aws ec2 register-image`
against LocalStack so the envoy-fleet Terraform module's `aws_ami_ids`
data lookup resolves.

## Attribution

The Salt `envoy/` state is structured after
[`cetanu/envoy-formula`](https://github.com/cetanu/envoy-formula)
(Apache 2.0). The HFT-grade tuning in `network/` and `hardening/` is
inspired by the blog series at
[`cetanu.github.io/blog`](https://cetanu.github.io/blog/):

- [NUMA](https://cetanu.github.io/blog/why-numa-is-important-in-trading/)
- [Real-time kernel patch](https://cetanu.github.io/blog/linux-is-not-a-realtime-system/)
- [TLB](https://cetanu.github.io/blog/translation-lookaside-buffer/)
