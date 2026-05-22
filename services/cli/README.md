# regnant CLI

Wraps the regnant Open Service Broker API plus a Keycloak device-code
login flow.

## Install

```bash
cargo install --path .
```

Static binaries for `linux/amd64`, `linux/arm64`, `darwin/amd64`, and
`darwin/arm64` are published as release artifacts.

## Authenticate

```bash
regnant auth login
# follow the URL printed; enter the displayed user code
regnant auth whoami
```

Refresh tokens are cached in the OS keychain via the `keyring` crate.
No tokens ever land on disk.

## Catalog

```bash
regnant catalog
```

## Load balancer instances

```bash
# Provision an LB pointed at the bitbucket-clone backend.
regnant lb create --product bitbucket --plan regnant-lb-pro-multi

# Check status.
regnant lb status <instance_id>

# Bind an app and retrieve credentials.
regnant lb bind --instance <instance_id> --app my-app

# Tear down.
regnant lb unbind --instance <instance_id> --binding <binding_id>
regnant lb delete <instance_id>
```

## Output formats

`--output table` (default), `--output json`, `--output yaml`.

## Environment

| Var | Default | Purpose |
|-----|---------|---------|
| `REGNANT_API_URL` | `http://localhost:8080` | OSB API base URL |
| `REGNANT_USERNAME` | `broker` | OSB basic-auth username |
| `REGNANT_PASSWORD` | `changeme` | OSB basic-auth password |
| `KEYCLOAK_REALM_URL` | `http://localhost:8090/realms/regnant` | OIDC issuer |
