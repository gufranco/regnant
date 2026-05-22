# EC2 key pair derived from a generated RSA key. The private key is
# stored in Secrets Manager; the public key is registered as a key pair
# so the Envoy fleet launch template can reference it.

resource "tls_private_key" "ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2" {
  key_name   = "${var.name_prefix}-fleet"
  public_key = tls_private_key.ec2.public_key_openssh

  tags = merge(local.module_tags, {
    Name = "${var.name_prefix}-fleet"
  })
}

resource "aws_secretsmanager_secret" "ec2_key" {
  name        = "${var.name_prefix}/ec2/private-key"
  description = "Private key matching the EC2 key pair used by the Envoy fleet."
  kms_key_id  = aws_kms_key.this["secrets"].arn
  tags        = local.module_tags

  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "ec2_key" {
  secret_id     = aws_secretsmanager_secret.ec2_key.id
  secret_string = tls_private_key.ec2.private_key_pem
}
