# Rotate mTLS keys

Rotation is a Terraform-only operation. The local CA's `tls_*`
resources derive a fresh root and re-mint every leaf when their
inputs change.

## Rotate every leaf

```bash
# Force regeneration by bumping the validity input.
tofu apply -var tls_validity_hours=$(( 8760 + RANDOM % 24 ))
```

This produces a new root certificate and new per-service leaves. Each
leaf is uploaded as a new Secrets Manager version. Sovereign's
secrets_context plugin picks up the new version within its refresh
interval (default 60 s) and pushes updated SDS material to Envoy.

## Rotate one service

If only one service's cert is compromised, scope the change:

```bash
tofu taint module.security.tls_private_key.leaf[\"osb-api\"]
tofu apply
```

Sovereign updates the SDS push for `osb-api-cert`. The service rotates
in place; existing TLS sessions continue with the old material until
they idle out.

## Rotate the root CA

```bash
tofu taint module.security.tls_private_key.ca
tofu taint module.security.tls_self_signed_cert.ca
tofu apply
```

Every leaf is re-signed. Brief outage on services that pin trust to
the old root; document a maintenance window before doing this in
production.

## Recovery

If rotation breaks traffic:

```bash
# Roll back the secret version.
aws --endpoint-url=http://localhost:4566 secretsmanager \
  restore-secret --secret-id regnant/leaf/envoy
```

Sovereign re-fetches and pushes the previous version.

## Cadence recommendations

| Rotation | Frequency |
|----------|-----------|
| Leaf certs | Monthly or on suspicion of compromise |
| Root CA | Annually |
| KMS keys | Automatic, AWS-managed |
| OSB broker credentials | Quarterly |
| Keycloak signing keys | Six-monthly |
