#!/usr/bin/env bash
# Restore from a backups/<timestamp> directory.
# Usage: scripts/restore.sh backups/2026-05-22T13-00-00Z

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -lt 1 ]]; then
  echo "usage: scripts/restore.sh backups/<timestamp>" >&2
  exit 1
fi

SRC="$1"
if [[ ! -d "$SRC" ]]; then
  echo "[restore] backup directory not found: $SRC" >&2
  exit 1
fi

LOCALSTACK_ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"

echo "[restore] DynamoDB"
for table_json in "$SRC"/dynamodb/*.json; do
  [[ -f "$table_json" ]] || continue
  table="$(basename "${table_json%.json}")"
  echo "[restore] -> $table"
  python3 - <<PY
import json, subprocess, sys
with open("${table_json}") as f:
    data = json.load(f)
for item in data.get("Items", []):
    subprocess.run([
        "aws", "--endpoint-url=${LOCALSTACK_ENDPOINT}", "--region", "${REGION}",
        "dynamodb", "put-item",
        "--table-name", "${table}",
        "--item", json.dumps(item),
    ], check=True, stdout=subprocess.DEVNULL)
PY
done

echo "[restore] S3"
for bucket_dir in "$SRC"/s3/*; do
  [[ -d "$bucket_dir" ]] || continue
  bucket="$(basename "$bucket_dir")"
  aws --endpoint-url="$LOCALSTACK_ENDPOINT" --region "$REGION" \
    s3 sync "$bucket_dir" "s3://${bucket}"
done

echo "[restore] Redis"
if [[ -f "$SRC/redis/dump.rdb" ]]; then
  docker compose cp "$SRC/redis/dump.rdb" redis:/data/dump.rdb
  docker compose restart redis
fi

echo "[restore] Keycloak"
if [[ -f "$SRC/keycloak/realm.json" ]]; then
  docker compose cp "$SRC/keycloak/realm.json" keycloak:/tmp/realm.json
  docker compose exec -T keycloak /opt/keycloak/bin/kc.sh import \
    --file /tmp/realm.json --override true
fi

echo "[restore] done"
