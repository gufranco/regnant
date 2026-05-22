#!/usr/bin/env bash
# Generate SPDX-JSON SBOMs for every regnant image via syft.
# Outputs land under sbom/<image>-<tag>.spdx.json (git-ignored).

set -euo pipefail

cd "$(dirname "$0")/.."

TAG="${1:-local}"
OUT_DIR=sbom
mkdir -p "$OUT_DIR"

if ! command -v syft >/dev/null 2>&1; then
  echo "[sbom] syft not installed (brew install syft)" >&2
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

for image in "${IMAGES[@]}"; do
  safe_name="${image//\//-}"
  output="$OUT_DIR/${safe_name}-${TAG}.spdx.json"
  if docker image inspect "${image}:${TAG}" >/dev/null 2>&1; then
    echo "[sbom] $image:$TAG -> $output"
    syft "${image}:${TAG}" -o spdx-json="${output}"
  else
    echo "[sbom] $image:$TAG not present; skipping"
  fi
done
