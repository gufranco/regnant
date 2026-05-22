# Inspect XDS

When traffic does not route correctly, the first thing to check is
what Sovereign is actually serving to Envoy.

## Sovereign UI

```
open http://localhost:8000/ui
```

Lists every node Sovereign knows about and every resource it serves to
each. Filter by node id (`envoy-1`, `envoy-2`, `envoy-3`).

## Resource APIs

```bash
# All clusters across all nodes
curl http://localhost:8000/clusters | jq

# Routes
curl http://localhost:8000/routes | jq

# Listeners
curl http://localhost:8000/listeners | jq

# What does node "envoy-1" actually receive?
curl http://localhost:8000/discovery?node=envoy-1 | jq
```

## Envoy admin

```bash
# Process-internal cluster view (what Envoy thinks)
curl http://localhost:9901/clusters

# Last config the node received
curl http://localhost:9901/config_dump | jq

# Stats prefix
curl http://localhost:9901/stats?filter=cluster.regnant
```

## Drift between Sovereign and Envoy

If Sovereign shows a cluster but Envoy does not:

1. Confirm the node id matches Sovereign's `matched_service` pattern.
2. Check `curl envoy:9901/server_info` for the boot timestamp; a stale
   node missed the push.
3. `docker compose restart envoy-1` to force a re-subscribe.

## When the OSB artifact is the problem

```bash
aws --endpoint-url=http://localhost:4566 s3 ls s3://regnant-osb-artifacts/envoy-resources/
aws --endpoint-url=http://localhost:4566 s3 cp s3://regnant-osb-artifacts/envoy-resources/<id>.yaml - | yq
```

If the YAML is malformed, the OSB Worker logged a parse error;
inspect with `docker compose logs osb-worker`.
