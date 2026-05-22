#!/usr/bin/env bash
# Snapshot every regnant data store to ./backups/<timestamp>/.
# - DynamoDB tables: dump as JSON via boto-flavored scan.
# - Redis: BGSAVE + copy of the dump.rdb out of the container.
# - Keycloak: export realm via kc.sh.
# - S3 buckets: sync object listing + objects.

set -euo pipefail

cd "$(dirname "$0")/.."

LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
OUT="backups/${STAMP}"
mkdir -p "$OUT/dynamodb" "$OUT/s3" "$OUT/redis" "$OUT/keycloak"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"

echo "[backup] DynamoDB"
for table in regnant-service-instances regnant-service-bindings; do
  aws --endpoint-url="$LOCALSTACK_ENDPOINT" --region "$REGION" \
    dynamodb scan --table-name "$table" \
    > "$OUT/dynamodb/${table}.json"
done

echo "[backup] S3"
for bucket in regnant-osb-artifacts regnant-observability-archive; do
  if aws --endpoint-url="$LOCALSTACK_ENDPOINT" --region "$REGION" s3 ls "s3://${bucket}" >/dev/null 2>&1; then
    mkdir -p "$OUT/s3/${bucket}"
    aws --endpoint-url="$LOCALSTACK_ENDPOINT" --region "$REGION" \
      s3 sync "s3://${bucket}" "$OUT/s3/${bucket}"
  fi
done

echo "[backup] Redis"
if docker compose ps --status running redis >/dev/null 2>&1; then
  docker compose exec -T redis redis-cli BGSAVE >/dev/null
  sleep 1
  docker compose cp redis:/data/dump.rdb "$OUT/redis/dump.rdb"
fi

echo "[backup] Keycloak"
if docker compose ps --status running keycloak >/dev/null 2>&1; then
  docker compose exec -T keycloak /opt/keycloak/bin/kc.sh export \
    --file /tmp/realm.json --realm regnant >/dev/null
  docker compose cp keycloak:/tmp/realm.json "$OUT/keycloak/realm.json"
fi

echo "[backup] done -> $OUT"
