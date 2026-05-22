# Keycloak realm configured via the mrparkers/keycloak provider.
# Owns the realm, three realm roles, three tier groups, three backend
# clients, the CLI public client, and demo users with matching tier
# group memberships.

resource "keycloak_realm" "regnant" {
  realm                        = var.realm_name
  enabled                      = true
  display_name                 = var.display_name
  registration_allowed         = false
  login_with_email_allowed     = true
  remember_me                  = true
  verify_email                 = false
  access_token_lifespan        = "${var.access_token_lifespan}s"
  sso_session_idle_timeout     = "1800s"
  sso_session_max_lifespan     = "36000s"
  offline_session_idle_timeout = "2592000s"

  ssl_required = "none"
}

resource "keycloak_role" "viewer" {
  realm_id    = keycloak_realm.regnant.id
  name        = "viewer"
  description = "Read-only access"
}

resource "keycloak_role" "editor" {
  realm_id    = keycloak_realm.regnant.id
  name        = "editor"
  description = "Read + write"
}

resource "keycloak_role" "admin" {
  realm_id    = keycloak_realm.regnant.id
  name        = "admin"
  description = "Full administrative access"
}

resource "keycloak_group" "free_tier" {
  realm_id = keycloak_realm.regnant.id
  name     = "free-tier"
}

resource "keycloak_group" "pro_tier" {
  realm_id = keycloak_realm.regnant.id
  name     = "pro-tier"
}

resource "keycloak_group" "enterprise_tier" {
  realm_id = keycloak_realm.regnant.id
  name     = "enterprise-tier"
}

resource "keycloak_group_roles" "free_tier" {
  realm_id = keycloak_realm.regnant.id
  group_id = keycloak_group.free_tier.id
  role_ids = [keycloak_role.viewer.id]
}

resource "keycloak_group_roles" "pro_tier" {
  realm_id = keycloak_realm.regnant.id
  group_id = keycloak_group.pro_tier.id
  role_ids = [keycloak_role.viewer.id, keycloak_role.editor.id]
}

resource "keycloak_group_roles" "enterprise_tier" {
  realm_id = keycloak_realm.regnant.id
  group_id = keycloak_group.enterprise_tier.id
  role_ids = [
    keycloak_role.viewer.id,
    keycloak_role.editor.id,
    keycloak_role.admin.id,
  ]
}

# Backend clients. Each is a bearer-only resource server.
resource "keycloak_openid_client" "backend" {
  for_each                     = toset(var.backends)
  realm_id                     = keycloak_realm.regnant.id
  client_id                    = each.key
  name                         = each.key
  enabled                      = true
  access_type                  = "BEARER-ONLY"
  standard_flow_enabled        = false
  implicit_flow_enabled        = false
  direct_access_grants_enabled = false
  service_accounts_enabled     = false
}

# Developer CLI: public client with the device-code flow enabled.
resource "keycloak_openid_client" "cli" {
  realm_id  = keycloak_realm.regnant.id
  client_id = var.cli_client_id
  name      = "regnant developer CLI"
  enabled   = true

  access_type                               = "PUBLIC"
  standard_flow_enabled                     = false
  implicit_flow_enabled                     = false
  direct_access_grants_enabled              = false
  service_accounts_enabled                  = false
  oauth2_device_authorization_grant_enabled = true
  use_refresh_tokens                        = true
}

# Demo users, one per tier.
resource "keycloak_user" "demo_viewer" {
  realm_id   = keycloak_realm.regnant.id
  username   = "demo-viewer"
  enabled    = true
  email      = "viewer@regnant.local"
  first_name = "Demo"
  last_name  = "Viewer"

  initial_password {
    value     = "demo"
    temporary = false
  }
}

resource "keycloak_user" "demo_editor" {
  realm_id   = keycloak_realm.regnant.id
  username   = "demo-editor"
  enabled    = true
  email      = "editor@regnant.local"
  first_name = "Demo"
  last_name  = "Editor"

  initial_password {
    value     = "demo"
    temporary = false
  }
}

resource "keycloak_user" "demo_admin" {
  realm_id   = keycloak_realm.regnant.id
  username   = "demo-admin"
  enabled    = true
  email      = "admin@regnant.local"
  first_name = "Demo"
  last_name  = "Admin"

  initial_password {
    value     = "demo"
    temporary = false
  }
}

resource "keycloak_user_groups" "demo_viewer" {
  realm_id  = keycloak_realm.regnant.id
  user_id   = keycloak_user.demo_viewer.id
  group_ids = [keycloak_group.free_tier.id]
}

resource "keycloak_user_groups" "demo_editor" {
  realm_id  = keycloak_realm.regnant.id
  user_id   = keycloak_user.demo_editor.id
  group_ids = [keycloak_group.pro_tier.id]
}

resource "keycloak_user_groups" "demo_admin" {
  realm_id  = keycloak_realm.regnant.id
  user_id   = keycloak_user.demo_admin.id
  group_ids = [keycloak_group.enterprise_tier.id]
}
