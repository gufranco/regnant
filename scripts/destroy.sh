#!/usr/bin/env bash
# Tear down: tofu destroy, then docker compose down (volumes optional).

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

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--keep-volumes]

  --keep-volumes  Do not remove docker volumes (default: remove).
USAGE
}

main() {
  local keep_volumes=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --keep-volumes) keep_volumes=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage; exit 1 ;;
    esac
  done

  local cli
  cli=$(pick_cli)

  if [[ -d "$ENV_DIR/.terraform" ]]; then
    echo "[destroy] $cli destroy"
    (cd "$ENV_DIR" && "$cli" destroy -input=false -auto-approve || true)
  fi

  echo "[destroy] docker compose down"
  if [[ $keep_volumes -eq 1 ]]; then
    docker compose down
  else
    docker compose down --volumes
  fi
}

main "$@"
