#!/usr/bin/env bash
# Smoke + E2E verification. Fast path by default; `--full` also runs
# the pytest e2e suite, terratest, and k6 smoke.

set -euo pipefail

cd "$(dirname "$0")/.."

readonly OSB_URL="${OSB_URL:-http://localhost:8080}"
readonly KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8090}"
readonly GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
readonly SOVEREIGN_URL="${SOVEREIGN_URL:-http://localhost:8000}"
readonly LOCALSTACK_URL="${LOCALSTACK_URL:-http://localhost:4566}"
readonly ENVOY_ADMIN_URLS=(
  "http://localhost:9901"
)

FULL=0
for arg in "$@"; do
  case "$arg" in
    --full) FULL=1 ;;
    -h|--help)
      cat <<USAGE
Usage: $(basename "$0") [--full]

  (default)   Smoke only: health endpoints on every public surface.
  --full      Smoke + terratest + pytest e2e + k6 smoke.
USAGE
      exit 0
      ;;
  esac
done

pass=0
fail=0

check() {
  local label="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    printf '  PASS  %s\n' "$label"
    pass=$((pass + 1))
  else
    printf '  FAIL  %s\n' "$label"
    fail=$((fail + 1))
  fi
}

echo "[verify] smoke"
check "LocalStack health" "curl -fsS '${LOCALSTACK_URL}/_localstack/health'"
check "Keycloak realm discovery" "curl -fsS '${KEYCLOAK_URL}/realms/regnant/.well-known/openid-configuration'"
check "OSB API health" "curl -fsS '${OSB_URL}/health'"
check "Sovereign clusters" "curl -fsS '${SOVEREIGN_URL}/clusters'"
check "Grafana health" "curl -fsS '${GRAFANA_URL}/api/health'"
for url in "${ENVOY_ADMIN_URLS[@]}"; do
  check "Envoy admin ready ($url)" "curl -fsS '${url}/ready'"
done

if [[ $FULL -eq 1 ]]; then
  echo
  echo "[verify] terratest"
  if command -v go >/dev/null 2>&1; then
    (cd tests/terratest && go test -v -count 1 -timeout 30m ./...) \
      && pass=$((pass + 1)) \
      || fail=$((fail + 1))
  else
    echo "  SKIP  go not installed"
  fi

  echo
  echo "[verify] pytest e2e"
  if command -v pytest >/dev/null 2>&1; then
    pytest -m e2e tests/e2e \
      && pass=$((pass + 1)) \
      || fail=$((fail + 1))
  else
    echo "  SKIP  pytest not installed"
  fi

  echo
  echo "[verify] k6 smoke"
  if command -v k6 >/dev/null 2>&1; then
    k6 run tests/load/k6_smoke.js \
      && pass=$((pass + 1)) \
      || fail=$((fail + 1))
  else
    echo "  SKIP  k6 not installed"
  fi
fi

echo
echo "[verify] $pass pass / $fail fail"
if (( fail > 0 )); then
  exit 1
fi
