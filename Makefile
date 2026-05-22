.DEFAULT_GOAL := help
.SHELLFLAGS := -eu -o pipefail -c
SHELL := /bin/bash
MAKEFLAGS += --no-print-directory

# Tooling overrides.
TOFU ?= tofu
TERRAFORM ?= terraform
COMPOSE ?= docker compose
PYTHON ?= python3
PACKER ?= packer
COSIGN ?= cosign
SYFT ?= syft
TRIVY ?= trivy
K6 ?= k6

ENV_DIR := terraform/envs/local
IMAGE_TAG ?= local
LOCALSTACK_ENDPOINT ?= http://localhost:4566
REGION ?= us-east-1

INFRA_SERVICES := localstack redis keycloak otel-collector prometheus grafana loki tempo promtail
APP_SERVICES := sovereign auth-sidecar ratelimit osb-api osb-worker \
                backend-jira-clone backend-confluence-clone backend-bitbucket-clone \
                envoy-1 envoy-2 envoy-3

IMAGES := regnant/envoy-fleet regnant/osb regnant/sovereign regnant/auth-sidecar regnant/ratelimit \
          regnant/backend-jira-clone regnant/backend-confluence-clone regnant/backend-bitbucket-clone \
          regnant/cli

##@ Help

.PHONY: help
help: ## Show this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
	  /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2 } \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

##@ Lifecycle

.PHONY: env
env: ## Create .env from .env.example on first run.
	@if [ ! -f .env ]; then \
	    echo "[env] creating .env from .env.example"; \
	    cp .env.example .env; \
	  fi

.PHONY: bootstrap
bootstrap: env ## Bring up the infra tier; app services follow when Dockerfiles exist.
	@echo "[bootstrap] checking docker compose"
	@$(COMPOSE) version >/dev/null
	@echo "[bootstrap] starting infrastructure tier"
	@$(COMPOSE) up -d $(INFRA_SERVICES)
	@echo "[bootstrap] waiting for LocalStack health"
	@for i in $$(seq 1 60); do \
	    if curl -fsS $(LOCALSTACK_ENDPOINT)/_localstack/health >/dev/null 2>&1; then \
	      echo "[bootstrap] LocalStack healthy"; break; \
	    fi; \
	    sleep 2; \
	  done
	@echo "[bootstrap] starting application tier (skipping services without a Dockerfile yet)"
	@ready=""; \
	  for svc in $(APP_SERVICES); do \
	    case $$svc in \
	      sovereign) [ -f services/sovereign/Dockerfile ] && ready="$$ready $$svc" ;; \
	      auth-sidecar) [ -f services/auth-sidecar/Dockerfile ] && ready="$$ready $$svc" ;; \
	      ratelimit) [ -f services/ratelimit/Dockerfile ] && ready="$$ready $$svc" ;; \
	      osb-api|osb-worker) [ -f services/osb/Dockerfile ] && ready="$$ready $$svc" ;; \
	      backend-jira-clone) [ -f services/backend-jira-clone/Dockerfile ] && ready="$$ready $$svc" ;; \
	      backend-confluence-clone) [ -f services/backend-confluence-clone/Dockerfile ] && ready="$$ready $$svc" ;; \
	      backend-bitbucket-clone) [ -f services/backend-bitbucket-clone/Dockerfile ] && ready="$$ready $$svc" ;; \
	      envoy-*) [ -f ami/docker/Dockerfile ] && ready="$$ready $$svc" ;; \
	    esac; \
	  done; \
	  if [ -n "$$ready" ]; then \
	    echo "[bootstrap] up -d --build:$$ready"; \
	    $(COMPOSE) up -d --build $$ready; \
	  else \
	    echo "[bootstrap] no application Dockerfiles present yet; run 'make build-ami' first"; \
	  fi
	@$(COMPOSE) ps

.PHONY: apply
apply: ## tofu apply against LocalStack; falls back to terraform.
	@cli=$$(command -v tofu || command -v terraform); \
	  if [ -z "$$cli" ]; then echo "[apply] neither tofu nor terraform on PATH" >&2; exit 1; fi; \
	  echo "[apply] using $$cli"; \
	  cd $(ENV_DIR) && \
	  $$cli init -input=false -upgrade && \
	  $$cli validate && \
	  $$cli plan -input=false -out=tfplan && \
	  $$cli apply -input=false tfplan && \
	  rm -f tfplan

.PHONY: seed
seed: ## Provision a few demo OSB instances and a binding.
	@OSB_URL=$${OSB_URL:-http://localhost:8080}; \
	  KEYCLOAK_URL=$${KEYCLOAK_URL:-http://localhost:8090}; \
	  USER=$${OSB_BROKER_USERNAME:-broker}; \
	  PASS=$${OSB_BROKER_PASSWORD:-changeme}; \
	  curl -fsS "$$KEYCLOAK_URL/realms/regnant/.well-known/openid-configuration" >/dev/null && \
	    echo "[seed] keycloak realm reachable"; \
	  prov () { \
	    curl -fsS -u "$$USER:$$PASS" \
	      -H 'X-Broker-API-Version: 2.16' -H 'content-type: application/json' \
	      -X PUT "$$OSB_URL/v2/service_instances/$$1?accepts_incomplete=true" \
	      -d "{\"service_id\":\"$$2\",\"plan_id\":\"$$3\",\"context\":{\"platform\":\"regnant-seed\"},\"parameters\":{\"upstream\":{\"host\":\"$$4\",\"port\":8080}}}" >/dev/null; \
	    printf '  provisioned %-12s -> %s\n' "$$1" "$$4"; \
	  }; \
	  JIRA="seed-jira-$$(date +%s)"; CONF="seed-conf-$$(date +%s)"; BITB="seed-bitb-$$(date +%s)"; \
	  prov "$$JIRA" regnant-lb-pro  regnant-lb-pro-single  backend-jira-clone; \
	  prov "$$CONF" regnant-lb-pro  regnant-lb-pro-multi   backend-confluence-clone; \
	  prov "$$BITB" regnant-lb-edge regnant-lb-edge-multi  backend-bitbucket-clone; \
	  BIND="seed-binding-$$(date +%s)"; \
	  curl -fsS -u "$$USER:$$PASS" \
	    -H 'X-Broker-API-Version: 2.16' -H 'content-type: application/json' \
	    -X PUT "$$OSB_URL/v2/service_instances/$$JIRA/service_bindings/$$BIND" \
	    -d "{\"service_id\":\"regnant-lb-pro\",\"plan_id\":\"regnant-lb-pro-single\",\"bind_resource\":{\"app_guid\":\"seed-app\"},\"parameters\":{\"app\":\"seed-app\"}}" >/dev/null && \
	    printf '  bound %s\n' "$$BIND"

.PHONY: verify
verify: ## Smoke health checks against every public endpoint.
	@pass=0; fail=0; \
	  check () { \
	    if eval "$$2" >/dev/null 2>&1; then printf '  PASS  %s\n' "$$1"; pass=$$((pass+1)); \
	    else printf '  FAIL  %s\n' "$$1"; fail=$$((fail+1)); fi; \
	  }; \
	  check "LocalStack health"           "curl -fsS $(LOCALSTACK_ENDPOINT)/_localstack/health"; \
	  check "Keycloak realm discovery"    "curl -fsS http://localhost:8090/realms/regnant/.well-known/openid-configuration"; \
	  check "OSB API health"              "curl -fsS http://localhost:8080/health"; \
	  check "Sovereign clusters"          "curl -fsS http://localhost:8000/clusters"; \
	  check "Grafana health"              "curl -fsS http://localhost:3000/api/health"; \
	  check "Envoy admin ready"           "curl -fsS http://localhost:9901/ready"; \
	  echo "[verify] $$pass pass / $$fail fail"; \
	  [ $$fail -eq 0 ]

.PHONY: verify-full
verify-full: verify ## Smoke + terratest + pytest e2e + k6 smoke.
	@if command -v go >/dev/null 2>&1; then \
	    echo "[verify-full] terratest"; \
	    (cd tests/terratest && go test -v -count 1 -timeout 30m ./...); \
	  else echo "[verify-full] go missing; skipping terratest"; fi
	@if command -v pytest >/dev/null 2>&1; then \
	    echo "[verify-full] pytest e2e"; \
	    pytest -m e2e tests/e2e; \
	  else echo "[verify-full] pytest missing; skipping e2e"; fi
	@if command -v $(K6) >/dev/null 2>&1; then \
	    echo "[verify-full] k6 smoke"; \
	    $(K6) run tests/load/k6_smoke.js; \
	  else echo "[verify-full] k6 missing; skipping smoke"; fi

.PHONY: destroy
destroy: ## tofu destroy + compose down (volumes preserved).
	@cli=$$(command -v tofu || command -v terraform); \
	  if [ -n "$$cli" ] && [ -d $(ENV_DIR)/.terraform ]; then \
	    echo "[destroy] $$cli destroy"; \
	    (cd $(ENV_DIR) && $$cli destroy -input=false -auto-approve) || true; \
	  fi
	@echo "[destroy] compose down"
	@$(COMPOSE) down

.PHONY: destroy-volumes
destroy-volumes: ## Like destroy but also removes named volumes.
	@cli=$$(command -v tofu || command -v terraform); \
	  if [ -n "$$cli" ] && [ -d $(ENV_DIR)/.terraform ]; then \
	    (cd $(ENV_DIR) && $$cli destroy -input=false -auto-approve) || true; \
	  fi
	@$(COMPOSE) down --volumes

##@ Build

.PHONY: build-ami
build-ami: ## Build the Envoy AMI image via Packer + Salt.
	@if ! command -v $(PACKER) >/dev/null 2>&1; then \
	    echo "[build-ami] packer not installed" >&2; exit 1; \
	  fi
	@echo "[build-ami] packer init"
	@$(PACKER) init ami/
	@echo "[build-ami] packer fmt -check"
	@$(PACKER) fmt -check ami/
	@echo "[build-ami] packer validate"
	@$(PACKER) validate \
	    -var "image_tag=$(IMAGE_TAG)" \
	    -var "localstack_endpoint=$(LOCALSTACK_ENDPOINT)" \
	    -var "region_label=$(REGION)" \
	    ami/
	@echo "[build-ami] packer build"
	@$(PACKER) build \
	    -var "image_tag=$(IMAGE_TAG)" \
	    -var "localstack_endpoint=$(LOCALSTACK_ENDPOINT)" \
	    -var "region_label=$(REGION)" \
	    ami/

.PHONY: build-images
build-images: ## Build every locally-built compose image.
	@$(COMPOSE) build

.PHONY: sign
sign: ## cosign-sign every locally built image.
	@if ! command -v $(COSIGN) >/dev/null 2>&1; then \
	    echo "[sign] cosign not installed" >&2; exit 1; \
	  fi
	@for image in $(IMAGES); do \
	    if docker image inspect "$$image:$(IMAGE_TAG)" >/dev/null 2>&1; then \
	      echo "[sign] $$image:$(IMAGE_TAG)"; \
	      if [ -f security/cosign/cosign.key ]; then \
	        $(COSIGN) sign --key security/cosign/cosign.key --yes "$$image:$(IMAGE_TAG)"; \
	      else \
	        COSIGN_EXPERIMENTAL=1 $(COSIGN) sign --yes "$$image:$(IMAGE_TAG)"; \
	      fi; \
	    fi; \
	  done

.PHONY: sbom
sbom: ## syft SPDX-JSON SBOMs per image into ./sbom.
	@if ! command -v $(SYFT) >/dev/null 2>&1; then \
	    echo "[sbom] syft not installed (brew install syft)" >&2; exit 1; \
	  fi
	@mkdir -p sbom
	@for image in $(IMAGES); do \
	    if docker image inspect "$$image:$(IMAGE_TAG)" >/dev/null 2>&1; then \
	      safe=$$(echo "$$image" | tr '/' '-'); \
	      echo "[sbom] $$image:$(IMAGE_TAG) -> sbom/$$safe-$(IMAGE_TAG).spdx.json"; \
	      $(SYFT) "$$image:$(IMAGE_TAG)" -o "spdx-json=sbom/$$safe-$(IMAGE_TAG).spdx.json"; \
	    fi; \
	  done

.PHONY: scan
scan: ## Trivy gate on HIGH,CRITICAL per image.
	@if ! command -v $(TRIVY) >/dev/null 2>&1; then \
	    echo "[scan] trivy not installed (brew install trivy)" >&2; exit 1; \
	  fi
	@mkdir -p scan-reports
	@failed=0; \
	  for image in $(IMAGES); do \
	    if docker image inspect "$$image:$(IMAGE_TAG)" >/dev/null 2>&1; then \
	      safe=$$(echo "$$image" | tr '/' '-'); \
	      out="scan-reports/$$safe-$(IMAGE_TAG).json"; \
	      echo "[scan] $$image:$(IMAGE_TAG) -> $$out"; \
	      $(TRIVY) image --severity HIGH,CRITICAL --exit-code 1 --format json \
	        --output "$$out" "$$image:$(IMAGE_TAG)" || failed=$$((failed+1)); \
	    fi; \
	  done; \
	  [ $$failed -eq 0 ] || { echo "[scan] $$failed image(s) failed" >&2; exit 1; }

##@ Quality

.PHONY: lint
lint: ## pre-commit on every file.
	@pre-commit run --all-files

.PHONY: fmt
fmt: ## Apply Terraform, Python, Rust formatters.
	@$(TOFU) -chdir=$(ENV_DIR) fmt -recursive
	@ruff format services/ tests/
	@cargo fmt --all --manifest-path services/cli/Cargo.toml
	@cargo fmt --all --manifest-path services/auth-sidecar/Cargo.toml
	@find envoy/filters -name Cargo.toml -execdir cargo fmt --all \;

.PHONY: test
test: verify-full ## Full test suite (alias for verify-full).

.PHONY: coverage
coverage: ## Per-language coverage with a 95% gate.
	@threshold=$${THRESHOLD:-95}; fail=0; \
	  echo "[coverage] python"; \
	  for d in services/*/; do \
	    if [ -f "$$d/pyproject.toml" ] && [ -d "$$d/tests" ]; then \
	      ( cd "$$d" && pytest --cov=. --cov-report=term-missing --cov-fail-under=$$threshold tests ) \
	        || fail=$$((fail+1)); \
	    fi; \
	  done; \
	  echo "[coverage] rust"; \
	  if cargo install --list 2>/dev/null | grep -q '^cargo-tarpaulin '; then \
	    for m in services/auth-sidecar/Cargo.toml services/cli/Cargo.toml \
	             envoy/filters/header-rewriter/Cargo.toml envoy/filters/ab-router/Cargo.toml \
	             envoy/filters/request-id-injector/Cargo.toml; do \
	      [ -f "$$m" ] && (cargo tarpaulin --manifest-path "$$m" --fail-under $$threshold --quiet || fail=$$((fail+1))); \
	    done; \
	  else echo "  SKIP cargo-tarpaulin not installed"; fi; \
	  echo "[coverage] go"; \
	  if command -v go >/dev/null 2>&1; then \
	    ( cd tests/terratest && go test -coverprofile=cover.out ./... ) || fail=$$((fail+1)); \
	    pct=$$(cd tests/terratest && go tool cover -func=cover.out | awk '/total:/ {gsub("%","");print int($$3)}'); \
	    echo "  total: $$pct%"; \
	    [ $$pct -ge $$threshold ] || fail=$$((fail+1)); \
	  else echo "  SKIP go not installed"; fi; \
	  [ $$fail -eq 0 ] || { echo "[coverage] $$fail language(s) below $$threshold%" >&2; exit 1; }

.PHONY: load-test
load-test: ## k6 sustained load with SLO thresholds.
	@if ! command -v $(K6) >/dev/null 2>&1; then echo "[load-test] k6 not installed" >&2; exit 1; fi
	@TARGET_URL=$${TARGET_URL:-https://localhost:8443} \
	  $(K6) run --insecure-skip-tls-verify tests/load/k6_sustained.js

##@ Operations

.PHONY: logs
logs: ## Tail compose logs across every service.
	@$(COMPOSE) logs -f --tail=200

.PHONY: status
status: ## Show compose service status.
	@$(COMPOSE) ps

.PHONY: rotate-keys
rotate-keys: ## Force re-mint of every mTLS leaf via Sovereign SDS.
	@cli=$$(command -v $(TOFU) || command -v $(TERRAFORM)); \
	  validity=$$((8760 + RANDOM % 24)); \
	  echo "[rotate-keys] new validity window: $$validity hours"; \
	  cd $(ENV_DIR) && $$cli apply -auto-approve -var tls_validity_hours=$$validity

.PHONY: backup
backup: ## Snapshot DynamoDB + S3 + Redis + Keycloak realm.
	@stamp=$$(date -u +%Y-%m-%dT%H-%M-%SZ); \
	  out="backups/$$stamp"; \
	  mkdir -p "$$out/dynamodb" "$$out/s3" "$$out/redis" "$$out/keycloak"; \
	  export AWS_ACCESS_KEY_ID=$${AWS_ACCESS_KEY_ID:-test}; \
	  export AWS_SECRET_ACCESS_KEY=$${AWS_SECRET_ACCESS_KEY:-test}; \
	  echo "[backup] DynamoDB"; \
	  for t in regnant-service-instances regnant-service-bindings; do \
	    aws --endpoint-url=$(LOCALSTACK_ENDPOINT) --region $(REGION) \
	      dynamodb scan --table-name "$$t" > "$$out/dynamodb/$$t.json" || true; \
	  done; \
	  echo "[backup] S3"; \
	  for b in regnant-osb-artifacts regnant-observability-archive; do \
	    if aws --endpoint-url=$(LOCALSTACK_ENDPOINT) --region $(REGION) s3 ls "s3://$$b" >/dev/null 2>&1; then \
	      mkdir -p "$$out/s3/$$b"; \
	      aws --endpoint-url=$(LOCALSTACK_ENDPOINT) --region $(REGION) s3 sync "s3://$$b" "$$out/s3/$$b"; \
	    fi; \
	  done; \
	  echo "[backup] Redis"; \
	  if $(COMPOSE) ps --status running redis >/dev/null 2>&1; then \
	    $(COMPOSE) exec -T redis redis-cli BGSAVE >/dev/null; sleep 1; \
	    $(COMPOSE) cp redis:/data/dump.rdb "$$out/redis/dump.rdb"; \
	  fi; \
	  echo "[backup] Keycloak"; \
	  if $(COMPOSE) ps --status running keycloak >/dev/null 2>&1; then \
	    $(COMPOSE) exec -T keycloak /opt/keycloak/bin/kc.sh export --file /tmp/realm.json --realm regnant >/dev/null || true; \
	    $(COMPOSE) cp keycloak:/tmp/realm.json "$$out/keycloak/realm.json" 2>/dev/null || true; \
	  fi; \
	  echo "[backup] done -> $$out"

.PHONY: restore
restore: ## Restore from a specific backup. Usage: make restore SRC=backups/<ts>
	@if [ -z "$(SRC)" ]; then echo "usage: make restore SRC=backups/<timestamp>" >&2; exit 1; fi
	@if [ ! -d "$(SRC)" ]; then echo "[restore] $(SRC) not found" >&2; exit 1; fi
	@export AWS_ACCESS_KEY_ID=$${AWS_ACCESS_KEY_ID:-test}; \
	  export AWS_SECRET_ACCESS_KEY=$${AWS_SECRET_ACCESS_KEY:-test}; \
	  echo "[restore] DynamoDB"; \
	  for f in $(SRC)/dynamodb/*.json; do \
	    [ -f "$$f" ] || continue; \
	    table=$$(basename "$$f" .json); \
	    $(PYTHON) -c "import json,subprocess,sys; data=json.load(open(sys.argv[1])); [subprocess.run(['aws','--endpoint-url=$(LOCALSTACK_ENDPOINT)','--region','$(REGION)','dynamodb','put-item','--table-name',sys.argv[2],'--item',json.dumps(i)],check=True,stdout=subprocess.DEVNULL) for i in data.get('Items',[])]" "$$f" "$$table"; \
	  done; \
	  echo "[restore] S3"; \
	  for d in $(SRC)/s3/*/; do \
	    [ -d "$$d" ] || continue; \
	    aws --endpoint-url=$(LOCALSTACK_ENDPOINT) --region $(REGION) s3 sync "$$d" "s3://$$(basename $$d)"; \
	  done; \
	  echo "[restore] Redis"; \
	  if [ -f $(SRC)/redis/dump.rdb ]; then \
	    $(COMPOSE) cp $(SRC)/redis/dump.rdb redis:/data/dump.rdb && $(COMPOSE) restart redis; \
	  fi; \
	  echo "[restore] Keycloak"; \
	  if [ -f $(SRC)/keycloak/realm.json ]; then \
	    $(COMPOSE) cp $(SRC)/keycloak/realm.json keycloak:/tmp/realm.json && \
	    $(COMPOSE) exec -T keycloak /opt/keycloak/bin/kc.sh import --file /tmp/realm.json --override true; \
	  fi; \
	  echo "[restore] done"
