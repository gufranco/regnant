# Identity module

Configures the Keycloak realm via the `mrparkers/keycloak` provider.
Keycloak runs as a docker-compose container; this module owns the
realm configuration that the container imports plus everything we'd
manage outside the initial realm-export.json once Terraform reaches it.

## What it manages

- Realm `regnant` with sensible token lifespans
- Three realm roles: `viewer`, `editor`, `admin`
- Three groups (`free-tier`, `pro-tier`, `enterprise-tier`) with role
  mappings (free = viewer, pro = viewer+editor, enterprise = all)
- Three backend bearer-only clients matching the backend service names
- One public client `regnant-cli` with the device-code flow enabled
- Three demo users (`demo-viewer`, `demo-editor`, `demo-admin`), each
  in the matching tier group, password `demo`

## Inputs

| Name | Default | Purpose |
|------|---------|---------|
| `name_prefix` | required | Resource name prefix |
| `realm_name` | `regnant` | Realm identifier |
| `display_name` | `regnant local` | Human label |
| `access_token_lifespan` | `900` | Token lifetime in seconds |
| `refresh_token_lifespan` | `28800` | Refresh lifetime in seconds |
| `backends` | three clones | Backend client ids |
| `cli_client_id` | `regnant-cli` | Public CLI client id |
| `tags` | `{}` | Metadata only |

## Outputs

`realm_id`, `realm_name`, `issuer_url`, `backend_client_ids`,
`cli_client_id`, `role_ids`, `group_ids`.

## Notes

- The realm-export.json file shipped under `identity/keycloak/` boots
  the realm before Terraform reaches it; this module reconciles
  whatever drift accumulates between boots.
- Demo passwords are documented; rotate them via the Keycloak admin
  console before exposing the realm beyond localhost.
- Production deployments should attach an external identity provider
  (Google, GitHub, SAML) and turn off the demo users; the structure
  here keeps that change surgical.
