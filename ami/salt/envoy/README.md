# envoy Salt state

Installs the Envoy proxy binary, drops a bootstrap template and an
entrypoint script that renders it at boot, and registers a systemd
unit. Pinned by `ENVOY_VERSION` environment variable passed in by
Packer.

The structure is inspired by [`cetanu/envoy-formula`](https://github.com/cetanu/envoy-formula)
(Apache 2.0). The state ships a simplified subset focused on the
regnant runtime: pinned binary, bootstrap template, entrypoint,
hardened systemd unit.

## Files

| File                        | Purpose                                            |
| --------------------------- | -------------------------------------------------- |
| `init.sls`                  | The Salt state definition                          |
| `files/bootstrap.yaml.tmpl` | Envoy bootstrap with XDS, OTel access logs, admin  |
| `files/envoy-entrypoint.sh` | Renders the template with env vars and execs envoy |
| `files/envoy.service`       | systemd unit with hardening directives             |

## Environment variables consumed by the entrypoint

| Variable              | Default            | Meaning                |
| --------------------- | ------------------ | ---------------------- |
| `ENVOY_NODE_ID`       | `envoy-<hostname>` | XDS node id            |
| `ENVOY_NODE_CLUSTER`  | `regnant-fleet`    | XDS service cluster    |
| `ENVOY_REGION`        | `us-east-1`        | Locality region        |
| `SOVEREIGN_XDS_HOST`  | `sovereign`        | XDS control plane host |
| `SOVEREIGN_XDS_PORT`  | `8080`             | XDS control plane port |
| `OTEL_COLLECTOR_HOST` | `otel-collector`   | OTel host              |
| `OTEL_COLLECTOR_PORT` | `4317`             | OTel OTLP gRPC port    |
| `ENVOY_LOG_LEVEL`     | `info`             | Envoy log level        |

## systemd unit hardening

`NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome=yes`,
`PrivateTmp=yes`, dropped capabilities except `CAP_NET_BIND_SERVICE`,
syscall filter `@system-service`. File descriptor and process limits
raised to 1M each.
