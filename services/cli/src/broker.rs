//! Thin HTTP client for the regnant OSB.

use anyhow::{Context, Result};
use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Clone)]
pub struct BrokerClient {
    client: Client,
    base_url: String,
    auth_header: String,
}

impl BrokerClient {
    pub fn new(base_url: &str, username: &str, password: &str) -> Self {
        let token = BASE64.encode(format!("{username}:{password}"));
        Self {
            client: Client::builder().build().expect("reqwest client"),
            base_url: base_url.trim_end_matches('/').to_string(),
            auth_header: format!("Basic {token}"),
        }
    }

    pub async fn catalog(&self) -> Result<Value> {
        let response = self
            .client
            .get(format!("{}/v2/catalog", self.base_url))
            .header("X-Broker-API-Version", "2.16")
            .header("Authorization", &self.auth_header)
            .send()
            .await
            .context("catalog request")?
            .error_for_status()
            .context("catalog response")?;
        response.json().await.context("catalog body")
    }

    pub async fn provision(&self, instance_id: &str, body: &ProvisionBody) -> Result<Value> {
        let response = self
            .client
            .put(format!(
                "{}/v2/service_instances/{instance_id}?accepts_incomplete=true",
                self.base_url,
            ))
            .header("X-Broker-API-Version", "2.16")
            .header("Authorization", &self.auth_header)
            .json(body)
            .send()
            .await
            .context("provision request")?
            .error_for_status()
            .context("provision response")?;
        response.json().await.context("provision body")
    }

    pub async fn fetch(&self, instance_id: &str) -> Result<Value> {
        let response = self
            .client
            .get(format!("{}/v2/service_instances/{instance_id}", self.base_url))
            .header("X-Broker-API-Version", "2.16")
            .header("Authorization", &self.auth_header)
            .send()
            .await
            .context("fetch request")?
            .error_for_status()
            .context("fetch response")?;
        response.json().await.context("fetch body")
    }

    pub async fn last_operation(&self, instance_id: &str) -> Result<Value> {
        let response = self
            .client
            .get(format!(
                "{}/v2/service_instances/{instance_id}/last_operation",
                self.base_url,
            ))
            .header("X-Broker-API-Version", "2.16")
            .header("Authorization", &self.auth_header)
            .send()
            .await
            .context("last_operation request")?
            .error_for_status()
            .context("last_operation response")?;
        response.json().await.context("last_operation body")
    }

    pub async fn deprovision(&self, instance_id: &str, service: &str, plan: &str) -> Result<Value> {
        let response = self
            .client
            .delete(format!(
                "{}/v2/service_instances/{instance_id}?accepts_incomplete=true&service_id={service}&plan_id={plan}",
                self.base_url,
            ))
            .header("X-Broker-API-Version", "2.16")
            .header("Authorization", &self.auth_header)
            .send()
            .await
            .context("deprovision request")?
            .error_for_status()
            .context("deprovision response")?;
        response.json().await.context("deprovision body")
    }

    pub async fn bind(&self, instance: &str, binding: &str, body: &BindBody) -> Result<Value> {
        let response = self
            .client
            .put(format!(
                "{}/v2/service_instances/{instance}/service_bindings/{binding}",
                self.base_url,
            ))
            .header("X-Broker-API-Version", "2.16")
            .header("Authorization", &self.auth_header)
            .json(body)
            .send()
            .await
            .context("bind request")?
            .error_for_status()
            .context("bind response")?;
        response.json().await.context("bind body")
    }

    pub async fn unbind(&self, instance: &str, binding: &str, service: &str, plan: &str) -> Result<Value> {
        let response = self
            .client
            .delete(format!(
                "{}/v2/service_instances/{instance}/service_bindings/{binding}?service_id={service}&plan_id={plan}",
                self.base_url,
            ))
            .header("X-Broker-API-Version", "2.16")
            .header("Authorization", &self.auth_header)
            .send()
            .await
            .context("unbind request")?
            .error_for_status()
            .context("unbind response")?;
        response.json().await.context("unbind body")
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ProvisionBody {
    pub service_id: String,
    pub plan_id: String,
    #[serde(skip_serializing_if = "serde_json::Value::is_null", default)]
    pub context: Value,
    #[serde(skip_serializing_if = "serde_json::Value::is_null", default)]
    pub parameters: Value,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct BindBody {
    pub service_id: String,
    pub plan_id: String,
    #[serde(skip_serializing_if = "serde_json::Value::is_null", default)]
    pub parameters: Value,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bind_resource: Option<Value>,
}
