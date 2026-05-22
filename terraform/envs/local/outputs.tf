# Outputs surfaced after `tofu apply`.
# Filled out as modules come online in later phases.

output "region" {
  description = "Synthetic region label used everywhere."
  value       = var.region_label
}

output "localstack_endpoint" {
  description = "Base URL where LocalStack is reachable."
  value       = var.localstack_endpoint
}

output "osb_api_url" {
  description = "Open Service Broker API base URL."
  value       = "http://localhost:8080"
}

output "sovereign_url" {
  description = "Sovereign XDS HTTP endpoint."
  value       = "http://localhost:8000"
}

output "envoy_admin_urls" {
  description = "Per-instance Envoy admin endpoints (localhost-only)."
  value = [
    for i in range(1, var.envoy_instance_count + 1) :
    "http://localhost:${9900 + i}"
  ]
}

output "grafana_url" {
  description = "Grafana UI."
  value       = "http://localhost:3000"
}

output "keycloak_url" {
  description = "Keycloak admin and OIDC issuer."
  value       = var.keycloak_url
}

output "prometheus_url" {
  description = "Prometheus UI."
  value       = "http://localhost:9090"
}

output "loki_url" {
  description = "Loki HTTP endpoint."
  value       = "http://localhost:3100"
}

output "tempo_url" {
  description = "Tempo HTTP endpoint."
  value       = "http://localhost:3200"
}
