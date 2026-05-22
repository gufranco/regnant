# Backup and restore

Local-state backups capture every data store that holds state across
restarts.

## What gets backed up

| Store | Output | Notes |
|-------|--------|-------|
| DynamoDB | `dynamodb/<table>.json` | `service_instances`, `service_bindings` |
| S3 buckets | `s3/<bucket>/` | `regnant-osb-artifacts`, `regnant-observability-archive` |
| Redis | `redis/dump.rdb` | Sovereign cache + Steward counters |
| Keycloak | `keycloak/realm.json` | Full realm export |

## Take a backup

```bash
make backup        # or bash scripts/backup.sh
```

Lands in `backups/<UTC timestamp>/`. The directory is local-only;
copy to S3 / Glacier / your offsite store as a follow-up step.

## RPO and RTO targets

| Tier | RPO | RTO |
|------|-----|-----|
| Local dev | best-effort | a few minutes |
| Production reference | 5 minutes | 30 minutes |

For the production reference target, replace this script with:
- DynamoDB: PITR + on-demand backups (already enabled in the OSB
  module).
- S3: cross-region replication on both buckets.
- Redis: ElastiCache automated snapshots every 15 minutes.
- Keycloak: realm export to S3 via a CronJob, plus DB snapshot.

## Restore

```bash
make restore SRC=backups/2026-05-22T13-00-00Z
# or
bash scripts/restore.sh backups/2026-05-22T13-00-00Z
```

The script restores in this order: DynamoDB rows, S3 objects, Redis
dump file (with a `redis restart`), Keycloak realm import.

## Validation after a restore

```bash
make verify
# Provision a known instance and confirm it lands as 'available'.
regnant lb create --product jira --plan regnant-lb-pro-single
```

If the smoke test fails, inspect:

1. `docker compose logs osb-worker` for Sovereign artifact write
   errors.
2. `aws --endpoint-url=http://localhost:4566 dynamodb scan --table-name regnant-service-instances`
   to confirm rows.
3. Sovereign `/clusters` to confirm XDS pushes resumed.
