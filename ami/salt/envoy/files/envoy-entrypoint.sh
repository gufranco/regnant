#!/usr/bin/env bash
# Render the bootstrap template and exec envoy.
set -euo pipefail

: "${ENVOY_NODE_ID:=envoy-$(hostname -s)}"
: "${ENVOY_NODE_CLUSTER:=regnant-fleet}"
: "${ENVOY_REGION:=us-east-1}"
: "${SOVEREIGN_XDS_HOST:=sovereign}"
: "${SOVEREIGN_XDS_PORT:=8080}"
: "${OTEL_COLLECTOR_HOST:=otel-collector}"
: "${OTEL_COLLECTOR_PORT:=4317}"

export ENVOY_NODE_ID ENVOY_NODE_CLUSTER ENVOY_REGION
export SOVEREIGN_XDS_HOST SOVEREIGN_XDS_PORT OTEL_COLLECTOR_HOST OTEL_COLLECTOR_PORT

# envsubst is not in slim images by default; use a python one-liner.
# shellcheck disable=SC2016
python3 -c '
import os, sys
with open(sys.argv[1], "r") as fh:
    data = fh.read()
for key, value in os.environ.items():
    data = data.replace(f"${{{key}}}", value)
with open(sys.argv[2], "w") as fh:
    fh.write(data)
' /etc/envoy/bootstrap.yaml.tmpl /etc/envoy/bootstrap.yaml

chown envoy:envoy /etc/envoy/bootstrap.yaml
chmod 0640 /etc/envoy/bootstrap.yaml

exec /usr/local/bin/envoy \
  --config-path /etc/envoy/bootstrap.yaml \
  --log-level "${ENVOY_LOG_LEVEL:-info}" \
  --service-cluster "$ENVOY_NODE_CLUSTER" \
  --service-node "$ENVOY_NODE_ID"
