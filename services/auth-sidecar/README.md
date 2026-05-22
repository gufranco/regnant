# auth-sidecar

Envoy `ext_authz` gRPC server that validates incoming JWTs against
Keycloak. On success, forwards `x-regnant-roles`, `x-regnant-subject`,
and `x-regnant-user` headers to the downstream filter chain.

## Build

```bash
cargo build --release
```

Requires protoc and tonic-build. The build.rs compiles
`proto/envoy/service/auth/v3/external_auth.proto`; vendor the Envoy
protobuf tree into `proto/` for offline builds.

## Run

```bash
KEYCLOAK_REALM_URL=http://keycloak:8080/realms/regnant \
AUTH_LISTEN_ADDR=0.0.0.0:9191 \
cargo run --release
```

## Behavior

- JWKS fetched once on first request and cached for five minutes.
- Tokens must include the configured issuer and a valid `kid` matching
  one of the realm's signing keys.
- 30-second leeway on the `exp` claim.
- Roles are read from `realm_access.roles` and joined with commas
  before being forwarded.

## Docker

A distroless Dockerfile sits alongside this README.
