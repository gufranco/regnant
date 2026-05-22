.DEFAULT_GOAL := help
.SHELLFLAGS := -eu -o pipefail -c
SHELL := /bin/bash

# Tooling
TOFU ?= tofu
TERRAFORM ?= terraform
COMPOSE ?= docker compose
PYTHON ?= python3
ENV_DIR := terraform/envs/local

##@ Help

.PHONY: help
help: ## Show this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
	  /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

##@ Lifecycle

.PHONY: bootstrap
bootstrap: ## Bring up docker compose with health-check wait.
	@bash scripts/bootstrap.sh

.PHONY: apply
apply: ## tofu apply against LocalStack.
	@bash scripts/apply.sh

.PHONY: destroy
destroy: ## tofu destroy and tear down compose.
	@bash scripts/destroy.sh

.PHONY: verify
verify: ## Smoke + E2E suite.
	@bash scripts/verify.sh

.PHONY: seed
seed: ## Seed Keycloak realm + demo OSB instances.
	@bash scripts/seed-data.sh

##@ Build

.PHONY: build-ami
build-ami: ## Build the Envoy AMI via Packer + Salt + cosign + SBOM + Trivy.
	@bash scripts/build-ami.sh

.PHONY: sign
sign: ## Cosign-sign every image produced by the build.
	@bash scripts/sign-images.sh

.PHONY: sbom
sbom: ## Generate SPDX SBOMs for every image.
	@bash scripts/generate-sbom.sh

.PHONY: scan
scan: ## Trivy-scan every image.
	@bash scripts/scan-images.sh

##@ Quality

.PHONY: lint
lint: ## Run all linters.
	@pre-commit run --all-files

.PHONY: fmt
fmt: ## Apply formatters.
	@$(TOFU) -chdir=$(ENV_DIR) fmt -recursive
	@ruff format services/ tests/
	@cargo fmt --all --manifest-path services/cli/Cargo.toml
	@cargo fmt --all --manifest-path services/auth-sidecar/Cargo.toml

.PHONY: test
test: ## Run all tests.
	@bash scripts/verify.sh --full

.PHONY: load-test
load-test: ## Run k6 sustained load test with SLO assertions.
	@bash scripts/load-test.sh

##@ Operations

.PHONY: rotate-keys
rotate-keys: ## Rotate mTLS keys via Sovereign SDS.
	@bash scripts/rotate-keys.sh

.PHONY: backup
backup: ## Dump DynamoDB, snapshot Redis, export Keycloak realm.
	@bash scripts/backup.sh

.PHONY: restore
restore: ## Restore from the latest backup.
	@bash scripts/restore.sh
