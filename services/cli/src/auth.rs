//! Keycloak device-code login flow + OS keychain refresh token cache.

use anyhow::{anyhow, Context, Result};
use keyring::Entry;
use reqwest::Client;
use serde::Deserialize;
use std::time::Duration;
use tokio::time::sleep;

const KEYRING_SERVICE: &str = "regnant-cli";

#[derive(Debug, Deserialize)]
struct DeviceCode {
    device_code: String,
    user_code: String,
    verification_uri_complete: Option<String>,
    verification_uri: String,
    interval: u64,
    expires_in: u64,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct TokenResponse {
    access_token: String,
    refresh_token: String,
    #[serde(default)]
    error: Option<String>,
}

#[allow(dead_code)]
pub struct Token {
    pub access_token: String,
    pub refresh_token: String,
    pub username: String,
}

pub async fn device_code_login(realm: &str, client_id: &str) -> Result<Token> {
    let http = Client::new();
    let realm = realm.trim_end_matches('/');

    let device: DeviceCode = http
        .post(format!("{realm}/protocol/openid-connect/auth/device"))
        .form(&[("client_id", client_id), ("scope", "openid profile email")])
        .send()
        .await
        .context("request device code")?
        .error_for_status()?
        .json()
        .await
        .context("device-code body")?;

    let display_uri = device
        .verification_uri_complete
        .clone()
        .unwrap_or_else(|| device.verification_uri.clone());
    println!("Open this URL to authenticate: {display_uri}");
    println!("(or enter user code {} at {})", device.user_code, device.verification_uri);

    let token_url = format!("{realm}/protocol/openid-connect/token");
    let started = std::time::Instant::now();
    let timeout = Duration::from_secs(device.expires_in);

    loop {
        if started.elapsed() > timeout {
            return Err(anyhow!("device-code flow expired"));
        }
        sleep(Duration::from_secs(device.interval)).await;

        let response = http
            .post(&token_url)
            .form(&[
                ("grant_type", "urn:ietf:params:oauth:grant-type:device_code"),
                ("device_code", device.device_code.as_str()),
                ("client_id", client_id),
            ])
            .send()
            .await?;

        if response.status().is_success() {
            let body: TokenResponse = response.json().await?;
            let username = decode_subject(&body.access_token);
            return Ok(Token {
                access_token: body.access_token,
                refresh_token: body.refresh_token,
                username,
            });
        }

        let body: TokenResponse = match response.json().await {
            Ok(v) => v,
            Err(_) => continue,
        };
        match body.error.as_deref() {
            Some("authorization_pending") => continue,
            Some("slow_down") => sleep(Duration::from_secs(2)).await,
            Some(err) => return Err(anyhow!("token endpoint error: {err}")),
            None => continue,
        }
    }
}

pub fn store_refresh_token(realm: &str, token: &str) -> Result<()> {
    let entry = Entry::new(KEYRING_SERVICE, realm)?;
    entry.set_password(token)?;
    Ok(())
}

pub fn current_user() -> Result<Option<String>> {
    let entries = ["http://localhost:8090/realms/regnant"];
    for realm in entries {
        if let Ok(entry) = Entry::new(KEYRING_SERVICE, realm) {
            if let Ok(token) = entry.get_password() {
                return Ok(Some(decode_subject(&token)));
            }
        }
    }
    Ok(None)
}

fn decode_subject(token: &str) -> String {
    use base64::engine::general_purpose::URL_SAFE_NO_PAD as B64;
    use base64::Engine;

    let parts: Vec<&str> = token.split('.').collect();
    if parts.len() < 2 {
        return "unknown".into();
    }
    let payload = match B64.decode(parts[1]) {
        Ok(bytes) => bytes,
        Err(_) => return "unknown".into(),
    };
    let json: serde_json::Value = match serde_json::from_slice(&payload) {
        Ok(v) => v,
        Err(_) => return "unknown".into(),
    };
    json.get("preferred_username")
        .and_then(|v| v.as_str())
        .or_else(|| json.get("sub").and_then(|v| v.as_str()))
        .unwrap_or("unknown")
        .to_string()
}
