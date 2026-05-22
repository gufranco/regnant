# View traces, logs, and metrics

Grafana at http://localhost:3000 is the entry point. Admin credentials
default to `admin` / `changeme`.

## Traces (Tempo)

1. **Explore** -> **Tempo**.
2. Search by service: `service.name="osb-api"`.
3. Service map view: see the topology Envoy + ext_authz + ratelimit
   + backend produces.
4. Click a span -> "Logs for this span" jumps to Loki filtered by
   `trace_id`.

## Logs (Loki)

```
{service="envoy-fleet"} | json | response_code >= 500
```

Useful filters:

| Filter | What it surfaces |
|--------|-----------------|
| `{service="osb-worker"}` | Worker dispatch decisions |
| `{service="auth-sidecar"} | json | level="warn"` | Token rejections |
| `{service="envoy-fleet"} | json | duration > 1s` | Slow requests |

## Metrics (Prometheus)

```
sum by (cluster) (rate(envoy_cluster_upstream_rq_total[5m]))
```

| Metric | Meaning |
|--------|---------|
| `envoy_cluster_upstream_rq_total` | Per-cluster RPS |
| `envoy_http_downstream_rq_5xx` | Edge errors |
| `osb_provision_seconds` | OSB Worker provisioning duration histogram |
| `sovereign_xds_push_seconds` | XDS push latency |

## SLOs

The Grafana dashboard `SLO Burn Rate` shows:

- Availability target: 99.5% per backend per 30-day window
- Latency target: p95 < 200 ms
- Error budget burn rate alerts at 1h and 6h windows

## Common diagnoses

- A backend's latency spikes but error rate is flat: ratelimit is
  shedding load. Confirm with `ratelimit_over_limit_total`.
- 401s climb after a long idle period: token rotation issue; check
  the auth sidecar's JWKS cache age in `auth_sidecar_jwks_age_seconds`.
- Envoy CPU climbs without RPS climb: a WASM filter is misbehaving.
  Disable the suspect filter via Sovereign's `extension_configs` and
  redeploy.
