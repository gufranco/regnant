# Local backend for the LocalStack environment.
# State stays inside the repo's terraform/envs/local/.terraform/state
# directory and is git-ignored. Real-AWS variants would replace this with
# an S3 backend + DynamoDB lock table.

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
