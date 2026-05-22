# Teardown

Two flavors: soft (keep volumes for next time) and hard (wipe
everything).

## Soft teardown

```bash
make destroy
```

Tears down Terraform state and stops the compose stack while keeping
named volumes (`localstack-data`, `redis-data`, `keycloak-data`,
`prometheus-data`, `grafana-data`, `loki-data`, `tempo-data`,
`promtail-positions`).

The next `make bootstrap` will boot back to roughly where you left
off.

## Hard teardown

```bash
bash scripts/destroy.sh
docker compose down --volumes
docker volume prune --force
rm -rf terraform/envs/local/.terraform terraform/envs/local/terraform.tfstate*
```

Wipes every persistent volume. The next bootstrap is a true clean
slate.

## Image cleanup

```bash
docker image prune --filter "label=regnant.image=envoy"
docker image rm regnant/envoy-fleet:local regnant/osb:local \
                regnant/sovereign:local regnant/auth-sidecar:local \
                regnant/ratelimit:local regnant/cli:local \
                regnant/backend-jira-clone:local \
                regnant/backend-confluence-clone:local \
                regnant/backend-bitbucket-clone:local 2>/dev/null || true
```

## Reclaim disk

```bash
docker system df            # see usage
docker system prune --all   # nuclear, all images on the host
```
