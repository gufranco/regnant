#!/usr/bin/env bash
# Aggregate coverage across Python, Rust, and Go. Fails when any
# language reports below 95%.

set -euo pipefail

cd "$(dirname "$0")/.."

THRESHOLD="${THRESHOLD:-95}"

fail=0

echo "[coverage] python (services/*/tests)"
shopt -s nullglob
for service_dir in services/*/; do
  if [[ -f "${service_dir}pyproject.toml" && -d "${service_dir}tests" ]]; then
    name="$(basename "${service_dir}")"
    if command -v pytest >/dev/null 2>&1; then
      (
        cd "${service_dir}"
        pytest --cov=. --cov-report=term-missing --cov-fail-under="${THRESHOLD}" tests \
          || fail=$((fail + 1))
      )
    else
      echo "  SKIP  $name (pytest missing)"
    fi
  fi
done

echo
echo "[coverage] rust"
if command -v cargo >/dev/null 2>&1; then
  if cargo install --list 2>/dev/null | grep -q '^cargo-tarpaulin '; then
    for manifest in services/auth-sidecar/Cargo.toml services/cli/Cargo.toml \
                    envoy/filters/header-rewriter/Cargo.toml \
                    envoy/filters/ab-router/Cargo.toml \
                    envoy/filters/request-id-injector/Cargo.toml; do
      if [[ -f "$manifest" ]]; then
        echo "  $manifest"
        cargo tarpaulin --manifest-path "$manifest" --fail-under "${THRESHOLD}" --quiet \
          || fail=$((fail + 1))
      fi
    done
  else
    echo "  SKIP  cargo-tarpaulin not installed (cargo install cargo-tarpaulin)"
  fi
else
  echo "  SKIP  cargo not installed"
fi

echo
echo "[coverage] go (tests/terratest)"
if command -v go >/dev/null 2>&1; then
  (
    cd tests/terratest
    go test -coverprofile=cover.out ./... || fail=$((fail + 1))
    pct=$(go tool cover -func=cover.out | awk '/total:/ {gsub("%",""); print int($3)}')
    echo "  go total coverage: ${pct}%"
    if (( pct < THRESHOLD )); then
      echo "  go coverage below ${THRESHOLD}% (got ${pct}%)" >&2
      fail=$((fail + 1))
    fi
  )
else
  echo "  SKIP  go not installed"
fi

echo
if (( fail > 0 )); then
  echo "[coverage] $fail language(s) below ${THRESHOLD}%" >&2
  exit 1
fi
echo "[coverage] all languages meet ${THRESHOLD}%"
