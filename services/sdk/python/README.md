# regnant Python SDK

Typed Python client for the regnant Open Service Broker. Hand-written
in this revision; CI regenerates from `services/osb/openapi.yaml` via
`openapi-python-client` so the symbols stay in sync with the broker.

## Install

```bash
pip install regnant-sdk
```

Or from this repo while iterating:

```bash
pip install ./services/sdk/python
```

## Use

```python
from regnant_sdk import RegnantClient, ProvisionRequest

client = RegnantClient("http://localhost:8080", "broker", "changeme")

catalog = client.get_catalog()
for service in catalog.services:
    print(service.id)

response = client.provision(
    "instance-123",
    ProvisionRequest(
        service_id="regnant-lb-pro",
        plan_id="regnant-lb-pro-single",
        parameters={"upstream": {"host": "backend-jira-clone", "port": 8080}},
    ),
)
print(response.operation)

state = client.last_operation("instance-123")
print(state.state)
```

The async counterparts (`aget_catalog`, `aprovision`,
`alast_operation`) are also exported.

## Regenerate from OpenAPI

```bash
pip install openapi-python-client
openapi-python-client generate \
  --path ../../osb/openapi.yaml \
  --config openapi-python-client.yaml
```

The generated package replaces `regnant_sdk/client.py` and
`regnant_sdk/models.py`. The `__init__` re-exports stay stable.
