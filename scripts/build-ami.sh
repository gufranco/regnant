#!/usr/bin/env bash
# Run the Packer pipeline against LocalStack. Produces a Docker image
# tagged regnant/envoy-fleet:local and registers a synthetic AMI in
# the LocalStack EC2 catalog so the envoy-fleet module's data lookup
# resolves.

set -euo pipefail

cd "$(dirname "$0")/.."

PACKER=${PACKER:-packer}
LOCALSTACK_ENDPOINT=${LOCALSTACK_ENDPOINT:-http://localhost:4566}
REGION=${REGION:-us-east-1}
IMAGE_TAG=${IMAGE_TAG:-local}
ENVOY_VERSION=${ENVOY_VERSION:-v1.34.1}

if ! command -v "$PACKER" >/dev/null 2>&1; then
  echo "[build-ami] packer is not installed" >&2
  exit 1
fi

echo "[build-ami] packer init"
"$PACKER" init ami/

echo "[build-ami] packer fmt -check"
"$PACKER" fmt -check ami/ || {
  echo "[build-ami] packer fmt failed; run: packer fmt ami/" >&2
  exit 1
}

echo "[build-ami] packer validate"
"$PACKER" validate \
  -var "envoy_version=$ENVOY_VERSION" \
  -var "image_tag=$IMAGE_TAG" \
  -var "localstack_endpoint=$LOCALSTACK_ENDPOINT" \
  -var "region_label=$REGION" \
  ami/

echo "[build-ami] packer build"
"$PACKER" build \
  -var "envoy_version=$ENVOY_VERSION" \
  -var "image_tag=$IMAGE_TAG" \
  -var "localstack_endpoint=$LOCALSTACK_ENDPOINT" \
  -var "region_label=$REGION" \
  ami/

echo "[build-ami] done"
