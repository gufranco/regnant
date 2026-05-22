# ADR-0004: Full OpenTelemetry observability stack

**Status:** accepted
**Date:** 2026-05-22

## Context

The platform needs metrics, logs, and traces from every service.

## Decision

Run a complete OTel pipeline in docker-compose: OpenTelemetry Collector
(contrib) receives OTLP from every service, fans out to Prometheus 3
for metrics, Loki 3 for logs (via Promtail tailing container logs), and
Tempo 2 for traces. Grafana 11 sits over all three with provisioned
datasources and dashboards.

Services emit OTLP via their language SDKs. Envoy uses
`envoy.access_loggers.open_telemetry` for access logs and the OTel
trace provider for spans.

## Alternatives Considered

### Logs + metrics only

Pros: ~3 fewer containers.
Cons: drops distributed tracing, which is the most useful signal for a
mesh of this shape.

### Bespoke (no OTel)

Pros: simpler integration per service.
Cons: every language re-implements the same plumbing; no portability.

## Consequences

### Positive

- One pipeline serves all three signal types.
- W3C trace context propagates naturally end-to-end.

### Negative

- ~6 extra containers in the local stack (collector, Prom, Grafana,
  Loki, Tempo, Promtail).

### Risks

- The Collector becomes a single point of failure for telemetry.
  Mitigation: per-host OTel agent on the Envoy AMI offloads buffering.
