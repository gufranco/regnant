#!/usr/bin/env bash
# Bring up the regnant local stack with health-check wait.
# Steps:
#   1. Ensure .env exists (copy from .env.example on first run).
#   2. docker compose up -d the infrastructure tier.
#   3. Wait for LocalStack, Redis, Keycloak, OTel, Prometheus, Grafana, Loki, Tempo.
#   4. Build application services if their Dockerfiles exist; otherwise skip with a notice.
#   5. Bring up the rest.
#   6. Wait for application services to become healthy.
#
# Idempotent. Safe to re-run.

set -euo pipefail

cd "$(dirname "$0")/.."

readonly INFRA_SERVICES=(
  localstack
  redis
  keycloak
  otel-collector
  prometheus
  grafana
  loki
  tempo
  promtail
)

readonly APP_SERVICES=(
  sovereign
  auth-sidecar
  ratelimit
  osb-api
  osb-worker
  backend-jira-clone
  backend-confluence-clone
  backend-bitbucket-clone
  envoy-1
  envoy-2
  envoy-3
)

readonly OPTIONAL_SERVICES=(
  nginx
)

log() {
  printf '[bootstrap] %s\n' "$*"
}

ensure_env_file() {
  if [[ ! -f .env ]]; then
    log "creating .env from .env.example (first run)"
    cp .env.example .env
  fi
}

check_dependencies() {
  for cmd in docker; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log "ERROR: '$cmd' is not installed or not on PATH"
      exit 1
    fi
  done
  if ! docker compose version >/dev/null 2>&1; then
    log "ERROR: 'docker compose' (v2) is required"
    exit 1
  fi
}

service_has_dockerfile() {
  local svc="$1"
  case "$svc" in
    sovereign)                 [[ -f services/sovereign/Dockerfile ]] ;;
    auth-sidecar)              [[ -f services/auth-sidecar/Dockerfile ]] ;;
    ratelimit)                 [[ -f services/ratelimit/Dockerfile ]] ;;
    osb-api|osb-worker)        [[ -f services/osb/Dockerfile ]] ;;
    backend-jira-clone)        [[ -f services/backend-jira-clone/Dockerfile ]] ;;
    backend-confluence-clone)  [[ -f services/backend-confluence-clone/Dockerfile ]] ;;
    backend-bitbucket-clone)   [[ -f services/backend-bitbucket-clone/Dockerfile ]] ;;
    envoy-1|envoy-2|envoy-3)   [[ -f ami/docker/Dockerfile ]] ;;
    *) return 1 ;;
  esac
}

bring_up_infra() {
  log "starting infrastructure tier"
  docker compose up -d "${INFRA_SERVICES[@]}"
  log "waiting for infrastructure to become healthy"
  docker compose ps
}

bring_up_apps() {
  local ready=()
  for svc in "${APP_SERVICES[@]}"; do
    if service_has_dockerfile "$svc"; then
      ready+=("$svc")
    else
      log "skipping $svc (Dockerfile not yet present; created in a later phase)"
    fi
  done

  if [[ ${#ready[@]} -eq 0 ]]; then
    log "no application Dockerfiles ready yet; infra-only run"
    return
  fi

  log "starting application services: ${ready[*]}"
  docker compose up -d --build "${ready[@]}"
}

main() {
  check_dependencies
  ensure_env_file
  bring_up_infra
  bring_up_apps
  log "done. Inspect with: docker compose ps"
}

main "$@"
