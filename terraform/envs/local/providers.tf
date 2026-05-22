# Provider configuration for the local environment.
# Every AWS service is pointed at LocalStack on localhost:4566.
# Dummy credentials are accepted by LocalStack and never reach AWS.

provider "aws" {
  region                      = var.region_label
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  default_tags {
    tags = {
      project     = "regnant"
      environment = "local"
      managed-by  = "opentofu"
    }
  }

  endpoints {
    s3             = var.localstack_endpoint
    sqs            = var.localstack_endpoint
    dynamodb       = var.localstack_endpoint
    ec2            = var.localstack_endpoint
    iam            = var.localstack_endpoint
    route53        = var.localstack_endpoint
    acm            = var.localstack_endpoint
    kms            = var.localstack_endpoint
    cloudformation = var.localstack_endpoint
    cloudfront     = var.localstack_endpoint
    cloudwatch     = var.localstack_endpoint
    logs           = var.localstack_endpoint
    sts            = var.localstack_endpoint
    elbv2          = var.localstack_endpoint
    autoscaling    = var.localstack_endpoint
    ssm            = var.localstack_endpoint
    secretsmanager = var.localstack_endpoint
  }
}

provider "tls" {}
provider "random" {}
provider "null" {}
provider "local" {}
provider "time" {}
provider "http" {}

provider "keycloak" {
  client_id     = "admin-cli"
  username      = var.keycloak_admin_username
  password      = var.keycloak_admin_password
  url           = var.keycloak_url
  realm         = "master"
  initial_login = false
}
