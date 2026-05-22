//! CLI command implementations.

use anyhow::{Context, Result};
use serde_json::json;
use uuid::Uuid;

use crate::auth;
use crate::broker::{BindBody, BrokerClient, ProvisionBody};
use crate::output::{print_value, Format};
use crate::{AuthCommand, LbCommand};

pub async fn catalog(api_url: &str, user: &str, pass: &str, format: Format) -> Result<()> {
    let client = BrokerClient::new(api_url, user, pass);
    let value = client.catalog().await?;
    print_value(&value, format)
}

pub async fn lb(cmd: LbCommand, api_url: &str, user: &str, pass: &str, format: Format) -> Result<()> {
    let client = BrokerClient::new(api_url, user, pass);
    match cmd {
        LbCommand::Create {
            service,
            plan,
            instance_id,
            product,
        } => {
            let instance_id = instance_id.unwrap_or_else(|| Uuid::new_v4().to_string());
            let mut parameters = json!({});
            if let Some(product) = product {
                parameters["upstream"] = json!({
                    "host": format!("backend-{product}-clone"),
                    "port": 8080,
                });
            }
            let body = ProvisionBody {
                service_id: service,
                plan_id: plan,
                context: json!({"platform": "regnant", "user": user}),
                parameters,
            };
            let response = client.provision(&instance_id, &body).await?;
            print_value(&json!({"instance_id": instance_id, "response": response}), format)
        }
        LbCommand::List => {
            // The OSB spec does not expose a list endpoint; emit a hint.
            let value = json!({
                "info": "OSB v2.16 has no list endpoint. Query DynamoDB or the OSB admin UI.",
            });
            print_value(&value, format)
        }
        LbCommand::Status { instance_id } => {
            let fetch = client.fetch(&instance_id).await?;
            let last = client.last_operation(&instance_id).await?;
            print_value(&json!({"instance": fetch, "last_operation": last}), format)
        }
        LbCommand::Delete {
            instance_id,
            service,
            plan,
        } => {
            let response = client.deprovision(&instance_id, &service, &plan).await?;
            print_value(&response, format)
        }
        LbCommand::Bind {
            instance,
            app,
            service,
            plan,
        } => {
            let binding_id = Uuid::new_v4().to_string();
            let body = BindBody {
                service_id: service,
                plan_id: plan,
                parameters: json!({"app": app}),
                bind_resource: Some(json!({"app_guid": app})),
            };
            let response = client.bind(&instance, &binding_id, &body).await?;
            print_value(&json!({"binding_id": binding_id, "response": response}), format)
        }
        LbCommand::Unbind {
            instance,
            binding,
            service,
            plan,
        } => {
            let response = client.unbind(&instance, &binding, &service, &plan).await?;
            print_value(&response, format)
        }
    }
}

pub async fn auth(cmd: AuthCommand) -> Result<()> {
    match cmd {
        AuthCommand::Login { realm, client_id } => {
            let token = auth::device_code_login(&realm, &client_id).await?;
            auth::store_refresh_token(&realm, &token.refresh_token).context("store refresh token")?;
            println!("logged in as {}", token.username);
            Ok(())
        }
        AuthCommand::Whoami => {
            match auth::current_user()? {
                Some(name) => println!("current user: {name}"),
                None => println!("not logged in"),
            }
            Ok(())
        }
    }
}
