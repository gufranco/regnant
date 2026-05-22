#!/usr/bin/env bash
# Scan every regnant image with Trivy. Exits non-zero if any image
# has HIGH or CRITICAL vulnerabilities.

set -euo pipefail

cd "$(dirname "$0")/.."

TAG="${1:-local}"
mkdir -p scan-reports

if ! command -v trivy >/dev/null 2>&1; then
  echo "[scan] trivy not installed (brew install trivy)" >&2
  exit 1
fi

readonly IMAGES=(
  regnant/envoy-fleet
  regnant/osb
  regnant/sovereign
  regnant/auth-sidecar
  regnant/ratelimit
  regnant/backend-jira-clone
  regnant/backend-confluence-clone
  regnant/backend-bitbucket-clone
  regnant/cli
)

failed=0
for image in "${IMAGES[@]}"; do
  if docker image inspect "${image}:${TAG}" >/dev/null 2>&1; then
    safe_name="${image//\//-}"
    output="scan-reports/${safe_name}-${TAG}.json"
    echo "[scan] $image:$TAG -> $output"
    if ! trivy image \
        --severity HIGH,CRITICAL \
        --exit-code 1 \
        --format json \
        --output "$output" \
        "${image}:${TAG}"; then
      failed=$((failed + 1))
      echo "[scan] FAILED: $image:$TAG" >&2
    fi
  else
    echo "[scan] $image:$TAG not present; skipping"
  fi
done

if (( failed > 0 )); then
  echo "[scan] $failed image(s) failed the HIGH/CRITICAL gate" >&2
  exit 1
fi
echo "[scan] all images clean"
