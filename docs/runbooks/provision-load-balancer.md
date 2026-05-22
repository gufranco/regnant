# Provision a load balancer

End-to-end walkthrough: a developer asks for a load balancer pointed
at the Jira-clone backend, gets credentials, and exercises a request.

## With the CLI

```bash
regnant auth login                                   # device-code flow against Keycloak
regnant catalog                                      # see the three offerings
regnant lb create --product jira --plan regnant-lb-pro-multi
# returns instance_id=<uuid>
regnant lb status <instance_id>                      # state: provisioning -> available
regnant lb bind --instance <instance_id> --app my-app
# returns binding credentials
```

## With curl

```bash
# 1. Catalog
curl -u broker:changeme http://localhost:8080/v2/catalog | jq

# 2. Provision asynchronously
INSTANCE=$(uuidgen)
curl -u broker:changeme \
     -H 'X-Broker-API-Version: 2.16' \
     -H 'content-type: application/json' \
     -X PUT \
     "http://localhost:8080/v2/service_instances/${INSTANCE}?accepts_incomplete=true" \
     -d '{"service_id":"regnant-lb-pro","plan_id":"regnant-lb-pro-multi","parameters":{"upstream":{"host":"backend-jira-clone","port":8080}}}'

# 3. Poll
curl -u broker:changeme \
     "http://localhost:8080/v2/service_instances/${INSTANCE}/last_operation"

# 4. Inspect the artifact Sovereign reads
aws --endpoint-url=http://localhost:4566 s3 ls s3://regnant-osb-artifacts/envoy-resources/

# 5. Exercise a request through Envoy
curl -k https://localhost:8443/issues -H "x-ab-key: test-user"
```

## What actually happened end-to-end

1. The CLI (or curl) sent a `PUT` to the OSB API.
2. The API wrote a row to DynamoDB and enqueued an SQS message.
3. The OSB Worker received the message, rendered a Sovereign-shaped
   YAML document, wrote it to S3, and updated DynamoDB to `available`.
4. Sovereign's S3 context plugin picked up the new artifact within the
   refresh interval (default 30 s).
5. Sovereign served the new cluster/route/listener via XDS to the
   Envoy fleet.
6. The next request entering nginx -> NLB -> Envoy hit the freshly
   added listener, was authorized by the auth sidecar, ratelimited by
   Steward, traced + logged by the OTel pipeline, then routed to the
   backend.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `last_operation` stuck on `in progress` | Worker not running | `docker compose ps osb-worker`; check logs |
| Sovereign /clusters empty | S3 artifact not visible | check `s3 ls` and Sovereign's context refresh interval |
| Envoy 503 | XDS not pushed yet or backend down | `curl envoy:9901/clusters` to inspect upstream health |
| 401 from Envoy | auth sidecar rejected the JWT | `regnant auth whoami`; re-login if expired |
