#!/usr/bin/env bash
# Sign every locally-built regnant image with cosign.
# Usage: scripts/sign-images.sh [tag]
# Requires cosign 2.4+ and either a keypair at security/cosign/cosign.key
# (with COSIGN_PASSWORD set) or COSIGN_EXPERIMENTAL=1 for keyless OIDC.

set -euo pipefail

cd "$(dirname "$0")/.."

TAG="${1:-local}"

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

if ! command -v cosign >/dev/null 2>&1; then
  echo "[sign] cosign not installed" >&2
  exit 1
fi

for image in "${IMAGES[@]}"; do
  if docker image inspect "${image}:${TAG}" >/dev/null 2>&1; then
    echo "[sign] $image:$TAG"
    if [[ -f security/cosign/cosign.key ]]; then
      cosign sign --key security/cosign/cosign.key --yes "${image}:${TAG}"
    else
      COSIGN_EXPERIMENTAL=1 cosign sign --yes "${image}:${TAG}"
    fi
  else
    echo "[sign] $image:$TAG not present locally; skipping"
  fi
done
