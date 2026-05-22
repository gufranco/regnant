output "kms_key_arns" {
  description = "Customer-managed KMS key ARNs, keyed by purpose."
  value = {
    for purpose, key in aws_kms_key.this : purpose => key.arn
  }
}

output "kms_key_ids" {
  description = "Customer-managed KMS key ids, keyed by purpose."
  value = {
    for purpose, key in aws_kms_key.this : purpose => key.key_id
  }
}

output "kms_alias_names" {
  description = "KMS alias names, keyed by purpose."
  value = {
    for purpose, alias in aws_kms_alias.this : purpose => alias.name
  }
}

output "iam_role_arns" {
  description = "Service role ARNs, keyed by service name."
  value = {
    for svc, role in aws_iam_role.service : svc => role.arn
  }
}

output "iam_role_names" {
  description = "Service role names, keyed by service name."
  value = {
    for svc, role in aws_iam_role.service : svc => role.name
  }
}

output "permission_boundary_arn" {
  description = "Permission boundary attached to every service role."
  value       = aws_iam_policy.permission_boundary.arn
}

output "ca_cert_pem" {
  description = "Public certificate of the regnant root CA."
  value       = tls_self_signed_cert.ca.cert_pem
}

output "ca_secret_arns" {
  description = "Secrets Manager ARNs holding the CA material."
  value = {
    cert = aws_secretsmanager_secret.ca_cert.arn
    key  = aws_secretsmanager_secret.ca_key.arn
  }
}

output "leaf_secret_arns" {
  description = "Per-service leaf bundle ARNs, keyed by service."
  value = {
    for svc, secret in aws_secretsmanager_secret.leaf_bundle : svc => secret.arn
  }
}

output "acm_certificate_arn" {
  description = "ACM certificate for the public edge."
  value       = aws_acm_certificate.edge.arn
}

output "key_pair_name" {
  description = "EC2 key pair name registered with AWS."
  value       = aws_key_pair.ec2.key_name
}

output "key_pair_secret_arn" {
  description = "Secrets Manager ARN holding the EC2 private key."
  value       = aws_secretsmanager_secret.ec2_key.arn
}

output "security_group_ids" {
  description = "Security group ids, keyed by tier."
  value = {
    envoy     = aws_security_group.envoy.id
    osb_api   = aws_security_group.osb_api.id
    sovereign = aws_security_group.sovereign.id
    redis     = aws_security_group.redis.id
  }
}
