#!/usr/bin/env bash
# tofu apply against the LocalStack environment.
# Falls back to terraform if tofu is not installed.

set -euo pipefail

cd "$(dirname "$0")/.."

readonly ENV_DIR="terraform/envs/local"

pick_cli() {
  if command -v tofu >/dev/null 2>&1; then
    echo tofu
  elif command -v terraform >/dev/null 2>&1; then
    echo terraform
  else
    echo "neither tofu nor terraform is installed" >&2
    exit 1
  fi
}

main() {
  local cli
  cli=$(pick_cli)

  echo "[apply] using $cli"
  (
    cd "$ENV_DIR"
    "$cli" init -input=false -upgrade
    "$cli" validate
    "$cli" plan -input=false -out=tfplan
    "$cli" apply -input=false tfplan
    rm -f tfplan
  )
}

main "$@"
