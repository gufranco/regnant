# Incident response

A working playbook for "the platform is down or degraded." Tailored
for the regnant local stack; the structure applies to the
production-shape variant too.

## Triage in order

1. **Confirm the symptom.** Hit the canonical golden path:
   ```bash
   curl -k https://localhost:8443/issues -o /dev/null -w '%{http_code}\n'
   ```
   200 with content = traffic flows; non-200 = real issue.

2. **Check Envoy.** The data-plane is the choke point.
   ```bash
   curl http://localhost:9901/clusters
   curl http://localhost:9901/stats?filter=cluster.regnant
   ```
   If clusters are absent, the control plane failed to push.
   If clusters are present but unhealthy, the upstream failed.

3. **Check Sovereign.** Walk back upstream.
   ```bash
   curl http://localhost:8000/clusters
   docker compose logs --tail 100 sovereign
   ```

4. **Check OSB.** If artifacts are missing, the worker failed.
   ```bash
   aws --endpoint-url=http://localhost:4566 s3 ls s3://regnant-osb-artifacts/envoy-resources/
   docker compose logs --tail 100 osb-worker
   ```

5. **Check the cross-cutting boxes.**
   - Auth sidecar logs for 401 floods
   - Steward logs for ratelimit drops
   - Keycloak `/health/ready` for OIDC outages

## Common incidents

### Edge returns 503 on all paths

- Likely: NLB target group has no healthy targets.
- Check: `curl http://localhost:9901/ready` on each Envoy.
- Fix: `docker compose restart envoy-1 envoy-2 envoy-3`.

### Authentication fails for all users

- Likely: Keycloak JWKS rotation invalidated cached keys.
- Check: `curl http://localhost:8090/realms/regnant/protocol/openid-connect/certs`
- Fix: restart the auth sidecar to refresh; do not restart Keycloak
  (that loses session state).

### Sovereign returns empty XDS

- Likely: S3 context plugin caught a malformed YAML and gave up.
- Check: `docker compose logs sovereign | grep -i 'malformed'`
- Fix: identify the bad artifact, delete it from S3, requeue from OSB.

### OSB queue depth grows

- Likely: worker is wedged on a poison message.
- Check: `docker compose logs osb-worker | tail -50`
- Fix: the worker DLQs after five receives. Drain the DLQ manually
  once the bug is fixed.

## After the incident

- Write a brief post-mortem in `docs/incidents/<date>.md`.
- File any follow-up work as GitHub issues with the `incident` label.
- If a runbook step was missing, add it.

## Severity labels

| Sev | Definition | Response |
|-----|------------|----------|
| 1 | Total platform outage | Page; respond within 5 min |
| 2 | One backend or one cross-cutting concern down | Respond within 30 min |
| 3 | Degraded but serving | Next business day |
| 4 | Cosmetic, dashboard issue | Sprint backlog |
