# Local CA. Root certificate signs per-service leaf certificates that
# Sovereign serves to Envoy via SDS. Private keys are stored in Secrets
# Manager; the public CA certificate is exposed as a module output and
# also written to Secrets Manager so containers can pull it on boot.

resource "tls_private_key" "ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "${var.name_prefix} root CA"
    organization = var.name_prefix
    country      = "US"
  }

  validity_period_hours = var.tls_validity_hours
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
    "key_encipherment",
  ]
}

resource "aws_secretsmanager_secret" "ca_cert" {
  name        = "${var.name_prefix}/ca/cert"
  description = "regnant local root CA certificate (public)"
  kms_key_id  = aws_kms_key.this["secrets"].arn
  tags        = local.module_tags

  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "ca_cert" {
  secret_id     = aws_secretsmanager_secret.ca_cert.id
  secret_string = tls_self_signed_cert.ca.cert_pem
}

resource "aws_secretsmanager_secret" "ca_key" {
  name        = "${var.name_prefix}/ca/key"
  description = "regnant local root CA private key"
  kms_key_id  = aws_kms_key.this["secrets"].arn
  tags        = local.module_tags

  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "ca_key" {
  secret_id     = aws_secretsmanager_secret.ca_key.id
  secret_string = tls_private_key.ca.private_key_pem
}

# Per-service leaf certificates. Each container loads its own leaf at
# startup from Secrets Manager; Sovereign also reads them to push via
# SDS so Envoy's filter chain has matching client certs.

resource "tls_private_key" "leaf" {
  for_each    = toset(var.mesh_services)
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "leaf" {
  for_each        = toset(var.mesh_services)
  private_key_pem = tls_private_key.leaf[each.key].private_key_pem

  subject {
    common_name  = "${each.key}.${var.domain_name}"
    organization = var.name_prefix
  }

  dns_names = [
    each.key,
    "${each.key}.${var.domain_name}",
    "${each.key}.regnant.svc",
  ]
}

resource "tls_locally_signed_cert" "leaf" {
  for_each = toset(var.mesh_services)

  cert_request_pem      = tls_cert_request.leaf[each.key].cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = var.tls_validity_hours

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}

resource "aws_secretsmanager_secret" "leaf_bundle" {
  for_each = toset(var.mesh_services)

  name        = "${var.name_prefix}/leaf/${each.key}"
  description = "mTLS leaf bundle for ${each.key} (cert + key + ca)"
  kms_key_id  = aws_kms_key.this["secrets"].arn
  tags = merge(local.module_tags, {
    service = each.key
  })
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "leaf_bundle" {
  for_each = toset(var.mesh_services)

  secret_id = aws_secretsmanager_secret.leaf_bundle[each.key].id
  secret_string = jsonencode({
    certificate_pem = tls_locally_signed_cert.leaf[each.key].cert_pem
    private_key_pem = tls_private_key.leaf[each.key].private_key_pem
    ca_cert_pem     = tls_self_signed_cert.ca.cert_pem
  })
}
