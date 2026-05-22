output "realm_id" {
  description = "Keycloak realm id."
  value       = keycloak_realm.regnant.id
}

output "realm_name" {
  description = "Keycloak realm name."
  value       = keycloak_realm.regnant.realm
}

output "issuer_url" {
  description = "OIDC issuer URL for the realm."
  value       = "${trimsuffix(replace(keycloak_realm.regnant.id, keycloak_realm.regnant.id, ""), "/")}realms/${keycloak_realm.regnant.realm}"
}

output "backend_client_ids" {
  description = "Keycloak client ids per backend."
  value       = { for k, c in keycloak_openid_client.backend : k => c.client_id }
}

output "cli_client_id" {
  description = "Public CLI client id."
  value       = keycloak_openid_client.cli.client_id
}

output "role_ids" {
  description = "Realm role ids by name."
  value = {
    viewer = keycloak_role.viewer.id
    editor = keycloak_role.editor.id
    admin  = keycloak_role.admin.id
  }
}

output "group_ids" {
  description = "Tier group ids."
  value = {
    free_tier       = keycloak_group.free_tier.id
    pro_tier        = keycloak_group.pro_tier.id
    enterprise_tier = keycloak_group.enterprise_tier.id
  }
}
