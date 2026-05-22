#!/usr/bin/env bash
# k6 sustained load test against the Envoy NLB. Asserts the SLO
# thresholds declared in tests/load/k6_sustained.js.

set -euo pipefail

cd "$(dirname "$0")/.."

TARGET_URL="${TARGET_URL:-https://localhost:8443}"
SCRIPT="${1:-tests/load/k6_sustained.js}"

if ! command -v k6 >/dev/null 2>&1; then
  echo "[load-test] k6 not installed (brew install k6)" >&2
  exit 1
fi

echo "[load-test] target=$TARGET_URL script=$SCRIPT"
TARGET_URL="$TARGET_URL" k6 run --insecure-skip-tls-verify "$SCRIPT"
