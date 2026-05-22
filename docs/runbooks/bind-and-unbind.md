# Bind and unbind

The OSB binding model gives consumer apps credentials scoped to a
specific instance. Bindings are reversible; the broker rotates the
credential on every new bind.

## Bind

```bash
regnant lb bind \
  --instance <instance_id> \
  --app my-app \
  --service regnant-lb-pro \
  --plan regnant-lb-pro-multi
```

The response contains:

```json
{
  "credentials": {
    "uri": "https://<instance>.internal.regnant.local",
    "username": "binding-<binding_id>",
    "password": "<random-token>"
  }
}
```

Pass these to the consuming application. The CLI does not store
binding credentials; print them to a `.netrc` or a secret manager of
your choice on the consumer side.

## Unbind

```bash
regnant lb unbind \
  --instance <instance_id> \
  --binding <binding_id> \
  --service regnant-lb-pro \
  --plan regnant-lb-pro-multi
```

After unbind the credentials no longer authenticate. Existing TLS
sessions continue until they idle out; new sessions get rejected by
the auth sidecar because the binding row is gone.

## Inspect a binding

```bash
curl -u broker:changeme \
  "http://localhost:8080/v2/service_instances/<instance>/service_bindings/<binding>"
```

## When a binding goes missing

If `regnant lb unbind` returns 404, the binding was already removed.
Check DynamoDB to confirm:

```bash
aws --endpoint-url=http://localhost:4566 dynamodb get-item \
  --table-name regnant-service-bindings \
  --key '{"binding_id":{"S":"<binding>"},"instance_id":{"S":"<instance>"}}'
```

## Rotation

The broker does not rotate live bindings. To rotate, unbind and
re-bind. A consumer that needs zero-downtime rotation should hold two
bindings active simultaneously and swap between them.
