# Observability

Three signals, one pipeline, one dashboard pane.

## Pipeline

Every service emits OTLP to the central collector. The collector fans
out by signal type:

- **Metrics** -> Prometheus 3 via remote-write
- **Logs** -> Loki 3 via the loki exporter
- **Traces** -> Tempo 2 via OTLP

Grafana 11 is the single pane of glass with all three datasources
provisioned and trace-to-log + trace-to-metrics correlations wired.

## SLOs

| Service | SLO | Window |
|---------|-----|--------|
| OSB API | 99.5% availability, p95 < 300ms | 30 days |
| Sovereign XDS | 99.9% availability, p99 push < 500ms | 30 days |
| Envoy fleet | p50 < 50ms, p95 < 200ms, error rate < 0.1% | 30 days |
| Auth sidecar | 99.95% availability, p95 < 100ms | 30 days |
| Steward ratelimit | 99.95% availability, p95 < 50ms | 30 days |

Burn-rate alerts fire at 1h and 6h windows on the error budget.

## Useful queries

### Promotional rate by product

```
sum by (product) (
  rate(envoy_http_downstream_rq_xx{response_code_class="2"}[5m])
)
```

### XDS push latency p95

```
histogram_quantile(0.95,
  sum by (le) (rate(sovereign_xds_push_seconds_bucket[5m]))
)
```

### OSB provisioning duration p99

```
histogram_quantile(0.99,
  sum by (le, op) (rate(osb_worker_op_seconds_bucket[5m]))
)
```

### Logs: rate limit drops in the last hour

```
{service="ratelimit"} | json | over_limit="true" |~ "[Pp]roduct"
```

### Traces: end-to-end provisioning span

In Tempo Explore, filter by `service.name="osb-api"` and
`span.name="PUT /v2/service_instances/{id}"`; click into the span,
follow the "service map" view to confirm the call flowed through
the worker, S3, and Sovereign.

## Dashboards

Pre-provisioned dashboards in Grafana:

| Title | What it shows |
|-------|---------------|
| Envoy Fleet Overview | RPS, error rates, latency by upstream |
| OSB Throughput and Latency | Provision queue depth, worker dispatch |
| Sovereign XDS Latency | Push latency, connected nodes, churn |
| Auth Sidecar | Token validation rate, JWKS cache age |
| Ratelimit | Allowed vs over-limit by product and tier |
| Backend Comparison | Jira/Confluence/Bitbucket clone deltas |
| SLO Burn Rate | Error budgets and burn windows |

## Adding a new metric

1. Emit it from the service using the OTel SDK or
   `prometheus_fastapi_instrumentator`.
2. Add a scrape job to `observability/prometheus.yml` if the metric
   isn't already reachable via the OTel pipeline.
3. Add a panel to one of the dashboards under
   `observability/grafana/dashboards/`.
4. Reload Grafana provisioning: `docker compose restart grafana`.
