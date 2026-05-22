# Bootstrap

Bring up the regnant local stack from a clean checkout.

## Prerequisites

- Docker 24+
- Docker Compose v2.30+
- OpenTofu 1.10+ (or Terraform 1.5.7+)
- Python 3.13 (only if you run service tests directly)
- Rust 1.83 (only if you build the Rust services locally)

## Steps

```bash
git clone git@github.com:gufranco/regnant.git
cd regnant
cp .env.example .env
pre-commit install --install-hooks  # optional, recommended
make bootstrap                       # docker compose up; waits for health
make build-ami                       # Packer + Salt -> Docker image + AMI catalog entry
make apply                           # tofu apply against LocalStack
make seed                            # Keycloak demo realm + a couple of demo OSB instances
make verify                          # smoke + E2E
```

## Verifying it came up

| Endpoint | Expectation |
|----------|------------|
| `curl http://localhost:4566/_localstack/health` | `services` map with everything `running` |
| `curl http://localhost:8080/health` | `{"status":"ok"}` |
| `curl http://localhost:8000/clusters` | empty array until OSB writes artifacts |
| `curl http://localhost:8090/realms/regnant/.well-known/openid-configuration` | OIDC discovery document |
| `open http://localhost:3000` | Grafana login, admin / changeme |
| `curl http://localhost:9901/ready` (any envoy) | `LIVE` |

## Common failures

- **`docker compose up` hangs on the localstack healthcheck**: bump
  `LS_TIMEOUT` env var to 120 and retry.
- **`tofu apply` fails on `aws_route53_zone`**: LocalStack Community
  Route53 needs the `route53` service enabled; check
  `LOCALSTACK_SERVICES` in `.env`.
- **`make build-ami` cannot find packer**: install it with
  `brew install hashicorp/tap/packer`.
- **Envoy admin returns 404 on `/ready`**: the bootstrap template has
  not been rendered; check the entrypoint logs for missing env vars.
