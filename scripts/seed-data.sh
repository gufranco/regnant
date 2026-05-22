#!/usr/bin/env bash
# Seed demo state into a freshly bootstrapped stack.
# - Confirms the Keycloak realm imported.
# - Provisions a few OSB instances pointing at each backend.
# - Creates a binding on one of them.

set -euo pipefail

cd "$(dirname "$0")/.."

OSB_URL="${OSB_URL:-http://localhost:8080}"
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8090}"
BROKER_USER="${OSB_BROKER_USERNAME:-broker}"
BROKER_PASS="${OSB_BROKER_PASSWORD:-changeme}"

echo "[seed] confirming Keycloak realm"
curl -fsS "${KEYCLOAK_URL}/realms/regnant/.well-known/openid-configuration" >/dev/null

provision() {
  local id="$1" service="$2" plan="$3" upstream="$4"
  curl -fsS -u "${BROKER_USER}:${BROKER_PASS}" \
    -H 'X-Broker-API-Version: 2.16' \
    -H 'content-type: application/json' \
    -X PUT \
    "${OSB_URL}/v2/service_instances/${id}?accepts_incomplete=true" \
    -d "{\"service_id\":\"${service}\",\"plan_id\":\"${plan}\",\"context\":{\"platform\":\"regnant-seed\"},\"parameters\":{\"upstream\":{\"host\":\"${upstream}\",\"port\":8080}}}" >/dev/null
  printf '  provisioned %-12s -> %s\n' "$id" "$upstream"
}

JIRA_ID="seed-jira-$(date +%s)"
CONF_ID="seed-conf-$(date +%s)"
BITB_ID="seed-bitb-$(date +%s)"

echo "[seed] provisioning three LBs"
provision "$JIRA_ID" "regnant-lb-pro"   "regnant-lb-pro-single"   "backend-jira-clone"
provision "$CONF_ID" "regnant-lb-pro"   "regnant-lb-pro-multi"    "backend-confluence-clone"
provision "$BITB_ID" "regnant-lb-edge"  "regnant-lb-edge-multi"   "backend-bitbucket-clone"

BIND_ID="seed-binding-$(date +%s)"
echo "[seed] binding an app to the jira-clone LB"
curl -fsS -u "${BROKER_USER}:${BROKER_PASS}" \
  -H 'X-Broker-API-Version: 2.16' \
  -H 'content-type: application/json' \
  -X PUT \
  "${OSB_URL}/v2/service_instances/${JIRA_ID}/service_bindings/${BIND_ID}" \
  -d "{\"service_id\":\"regnant-lb-pro\",\"plan_id\":\"regnant-lb-pro-single\",\"bind_resource\":{\"app_guid\":\"seed-app\"},\"parameters\":{\"app\":\"seed-app\"}}" >/dev/null

printf '  bound %s\n' "$BIND_ID"
echo "[seed] done"
