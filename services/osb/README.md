# regnant OSB

Open Service Broker v2.16 implementation plus an asynchronous worker.
The API and Worker share a Python package and ship from the same
Dockerfile via two final stages (`api` and `worker`).

## Endpoints

| Method   | Path                                                               | Purpose                                                      |
| -------- | ------------------------------------------------------------------ | ------------------------------------------------------------ |
| `GET`    | `/v2/catalog`                                                      | Service offerings: lb-basic, lb-pro, lb-edge, two plans each |
| `PUT`    | `/v2/service_instances/{id}`                                       | Async provision; enqueues, returns 202                       |
| `PATCH`  | `/v2/service_instances/{id}`                                       | Async update                                                 |
| `DELETE` | `/v2/service_instances/{id}`                                       | Async deprovision                                            |
| `GET`    | `/v2/service_instances/{id}`                                       | Fetch instance                                               |
| `GET`    | `/v2/service_instances/{id}/last_operation`                        | Poll for state                                               |
| `PUT`    | `/v2/service_instances/{id}/service_bindings/{bid}`                | Create binding                                               |
| `DELETE` | `/v2/service_instances/{id}/service_bindings/{bid}`                | Delete binding                                               |
| `GET`    | `/v2/service_instances/{id}/service_bindings/{bid}`                | Fetch binding                                                |
| `GET`    | `/v2/service_instances/{id}/service_bindings/{bid}/last_operation` | Poll binding state                                           |
| `GET`    | `/health`                                                          | Liveness                                                     |
| `GET`    | `/metrics`                                                         | Prometheus exposition                                        |

HTTP Basic auth as required by the spec. Credentials read from env.

## Worker behavior

- Long-polls SQS provision-tasks and binding-tasks with 20s wait.
- For each `provision`/`update`, renders Sovereign-shaped YAML via
  `osb.sovereign_yaml` and writes it to S3 at
  `envoy-resources/<instance_id>.yaml`. Sovereign's S3 context plugin
  picks it up and produces the XDS resources Envoy consumes.
- Idempotency key is the SQS message id; DDB writes use conditional
  expressions to prevent duplicate provisions.
- DLQ via redrive after 5 receives, handled by the OSB module's queue
  policy.

## Local run

```bash
docker compose up -d osb-api osb-worker
curl -u broker:changeme http://localhost:8080/v2/catalog
```

## Layout

```
osb/
  api/               FastAPI app, basic auth, route handlers, deps
  worker/            Asyncio SQS consumer + dispatch
  catalog.py         Static catalog
  config.py          Pydantic settings
  exceptions.py      Domain errors
  observability.py   structlog + OTel tracer setup
  schemas.py         OSB API request/response models
  sovereign_yaml.py  Render Sovereign-shaped Envoy resources
  storage.py         DDB + S3 + SQS wrappers
tests/               pytest, real LocalStack backend, 95% gate
```
