# Security groups per tier. Egress is broad in local dev. Ingress is
# scoped to the VPC CIDR or to sibling SGs by reference.

resource "aws_security_group" "envoy" {
  name        = "${var.name_prefix}-sg-envoy"
  description = "Envoy data plane: 443 from edge, 9901 admin from VPC only"
  vpc_id      = var.vpc_id

  tags = merge(local.module_tags, {
    Name = "${var.name_prefix}-sg-envoy"
  })
}

resource "aws_security_group_rule" "envoy_ingress_https" {
  type              = "ingress"
  security_group_id = aws_security_group.envoy.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Public HTTPS to the Envoy fleet"
}

resource "aws_security_group_rule" "envoy_ingress_admin" {
  type              = "ingress"
  security_group_id = aws_security_group.envoy.id
  from_port         = 9901
  to_port           = 9901
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "Envoy admin endpoint, VPC only"
}

resource "aws_security_group_rule" "envoy_ingress_xds" {
  type              = "ingress"
  security_group_id = aws_security_group.envoy.id
  from_port         = 10000
  to_port           = 10000
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "Backend traffic from the NLB"
}

resource "aws_security_group_rule" "envoy_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.envoy.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Outbound to upstreams and the OTel collector"
}

resource "aws_security_group" "osb_api" {
  name        = "${var.name_prefix}-sg-osb-api"
  description = "OSB API: 8080 from VPC"
  vpc_id      = var.vpc_id

  tags = merge(local.module_tags, {
    Name = "${var.name_prefix}-sg-osb-api"
  })
}

resource "aws_security_group_rule" "osb_api_ingress" {
  type              = "ingress"
  security_group_id = aws_security_group.osb_api.id
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "OSB API HTTP from VPC"
}

resource "aws_security_group_rule" "osb_api_egress" {
  type              = "egress"
  security_group_id = aws_security_group.osb_api.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Outbound to AWS APIs and OTel collector"
}

resource "aws_security_group" "sovereign" {
  name        = "${var.name_prefix}-sg-sovereign"
  description = "Sovereign XDS: 8080 from VPC"
  vpc_id      = var.vpc_id

  tags = merge(local.module_tags, {
    Name = "${var.name_prefix}-sg-sovereign"
  })
}

resource "aws_security_group_rule" "sovereign_ingress" {
  type              = "ingress"
  security_group_id = aws_security_group.sovereign.id
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "Sovereign HTTP/JSON XDS from VPC"
}

resource "aws_security_group_rule" "sovereign_egress" {
  type              = "egress"
  security_group_id = aws_security_group.sovereign.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Outbound to AWS APIs, Redis, OTel collector"
}

resource "aws_security_group" "redis" {
  name        = "${var.name_prefix}-sg-redis"
  description = "Redis: 6379 from Sovereign and ratelimit"
  vpc_id      = var.vpc_id

  tags = merge(local.module_tags, {
    Name = "${var.name_prefix}-sg-redis"
  })
}

resource "aws_security_group_rule" "redis_ingress" {
  type              = "ingress"
  security_group_id = aws_security_group.redis.id
  from_port         = 6379
  to_port           = 6379
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "Redis from VPC"
}
