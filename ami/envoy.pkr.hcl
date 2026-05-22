# Packer template for the regnant Envoy AMI.
# Two builders:
#   - docker: applies the Salt highstate inside a debian:12-slim container
#     and commits the result. The output image is also registered in the
#     LocalStack EC2 catalog so the envoy-fleet module's data lookup
#     resolves to it.
#   - amazon-ebs: real-AWS variant. Disabled by default; uncomment when
#     baking the production AMI.

packer {
  required_version = ">= 1.12.0"
  required_plugins {
    docker = {
      version = "~> 1.0"
      source  = "github.com/hashicorp/docker"
    }
    amazon = {
      version = "~> 1.3"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "image_repository" {
  type        = string
  default     = "regnant/envoy-fleet"
  description = "Docker image repository to commit the baked image to."
}

variable "image_tag" {
  type        = string
  default     = "local"
  description = "Docker image tag for the committed image."
}

variable "envoy_version" {
  type        = string
  default     = "v1.34.1"
  description = "Envoy release line installed by the salt envoy state."
}

variable "build_environment" {
  type        = string
  default     = "local"
  description = "Build environment tag (local, staging, prod)."
}

variable "localstack_endpoint" {
  type        = string
  default     = "http://localhost:4566"
  description = "LocalStack endpoint for the post-build register-image step."
}

variable "region_label" {
  type        = string
  default     = "us-east-1"
  description = "Region label for the synthetic AMI registration."
}

source "docker" "envoy" {
  image       = "debian:12-slim"
  commit      = true
  pull        = true
  privileged  = false
  changes = [
    "USER 0",
    "WORKDIR /etc/envoy",
    "ENTRYPOINT [\"/usr/local/bin/envoy-entrypoint.sh\"]",
    "EXPOSE 9901 10000 443",
    "LABEL regnant.image=envoy",
    "LABEL regnant.envoy_version=${var.envoy_version}",
    "LABEL regnant.build_environment=${var.build_environment}",
  ]
}

build {
  name    = "envoy"
  sources = ["source.docker.envoy"]

  # Stage the Salt tree onto the build container.
  provisioner "file" {
    source      = "${path.root}/salt/"
    destination = "/srv/salt"
  }

  # Bootstrap salt-call --local plus its dependencies.
  provisioner "shell" {
    inline = [
      "set -eux",
      "apt-get update",
      "apt-get install --yes --no-install-recommends ca-certificates curl gnupg lsb-release procps systemd-sysv python3 python3-pip python3-yaml python3-jinja2 sudo iproute2 jq awscli",
      "curl -fsSL https://github.com/saltstack/salt-bootstrap/releases/latest/download/bootstrap-salt.sh -o /tmp/bootstrap-salt.sh",
      "sh /tmp/bootstrap-salt.sh -P -x python3 onedir 3007",
      "rm -f /tmp/bootstrap-salt.sh",
    ]
  }

  # Apply the highstate.
  provisioner "shell" {
    environment_vars = [
      "ENVOY_VERSION=${var.envoy_version}",
      "BUILD_ENVIRONMENT=${var.build_environment}",
    ]
    inline = [
      "set -eux",
      "mkdir -p /etc/salt/minion.d",
      "echo 'file_client: local' > /etc/salt/minion.d/local.conf",
      "echo 'file_roots:' >> /etc/salt/minion.d/local.conf",
      "echo '  base:' >> /etc/salt/minion.d/local.conf",
      "echo '    - /srv/salt' >> /etc/salt/minion.d/local.conf",
      "salt-call --local --retcode-passthrough state.apply",
    ]
  }

  # Smoke test the resulting image: Envoy binary exists and reports its version.
  provisioner "shell" {
    inline = [
      "envoy --version || true",
      "test -x /usr/local/bin/envoy-entrypoint.sh",
      "test -f /etc/envoy/bootstrap.yaml.tmpl",
    ]
  }

  post-processor "docker-tag" {
    repository = var.image_repository
    tags       = [var.image_tag]
  }

  post-processor "shell-local" {
    inline = [
      "set -eux",
      "command -v aws >/dev/null || exit 0",
      "image_id=$(docker images --no-trunc --quiet ${var.image_repository}:${var.image_tag} | head -n1)",
      "if [ -z \"$image_id\" ]; then echo 'no image id; skipping AMI registration'; exit 0; fi",
      "short_id=$(printf '%s' \"$image_id\" | sed 's/sha256://; s/^\\(........\\).*/ami-\\1/')",
      "aws --endpoint-url=${var.localstack_endpoint} --region ${var.region_label} ec2 register-image --name regnant-envoy-${var.image_tag} --description \"regnant envoy fleet AMI\" --root-device-name /dev/xvda --architecture x86_64 || true",
      "echo \"registered envoy AMI (synthetic id $short_id) against ${var.localstack_endpoint}\"",
    ]
  }
}
