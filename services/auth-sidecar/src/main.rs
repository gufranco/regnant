//! Envoy ext_authz gRPC sidecar.
//!
//! Validates incoming JWTs against the Keycloak realm's JWKS endpoint
//! and returns OK/PermissionDenied. On success it forwards the user's
//! roles to the downstream filter chain via `x-regnant-roles`.

use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::{Duration, Instant};

use anyhow::{anyhow, Context, Result};
use jsonwebtoken::{decode, decode_header, Algorithm, DecodingKey, Validation};
use parking_lot::RwLock;
use serde::Deserialize;
use tonic::{transport::Server, Request, Response, Status};
use tracing::{error, info, warn};
use tracing_subscriber::EnvFilter;

#[allow(clippy::all)]
#[allow(unused_qualifications)]
mod envoy {
    pub mod service {
        pub mod auth {
            pub mod v3 {
                tonic::include_proto!("envoy.service.auth.v3");
            }
        }
    }
    pub mod config {
        pub mod core {
            pub mod v3 {
                tonic::include_proto!("envoy.config.core.v3");
            }
        }
    }
    pub mod r#type {
        pub mod v3 {
            tonic::include_proto!("envoy.r#type.v3");
        }
        pub mod matcher {
            pub mod v3 {
                tonic::include_proto!("envoy.r#type.matcher.v3");
            }
        }
    }
}

use envoy::service::auth::v3::{
    authorization_server::{Authorization, AuthorizationServer},
    check_response, CheckRequest, CheckResponse, DeniedHttpResponse, OkHttpResponse,
};

#[derive(Debug, Clone, Deserialize)]
struct Jwks {
    keys: Vec<JwksKey>,
}

#[derive(Debug, Clone, Deserialize)]
#[allow(dead_code)]
struct JwksKey {
    kty: String,
    kid: String,
    #[serde(default)]
    alg: Option<String>,
    #[serde(default)]
    r#use: Option<String>,
    n: Option<String>,
    e: Option<String>,
    x: Option<String>,
    y: Option<String>,
    crv: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
struct Claims {
    #[serde(default)]
    sub: String,
    #[serde(default)]
    iss: String,
    #[serde(default)]
    aud: serde_json::Value,
    #[serde(default)]
    exp: i64,
    #[serde(default)]
    realm_access: RealmAccess,
    #[serde(default)]
    preferred_username: String,
}

#[derive(Debug, Default, Clone, Deserialize)]
struct RealmAccess {
    #[serde(default)]
    roles: Vec<String>,
}

struct JwksCache {
    keys: HashMap<String, DecodingKey>,
    expires_at: Instant,
}

#[derive(Clone)]
struct AuthService {
    realm_url: String,
    issuer: String,
    cache: Arc<RwLock<Option<JwksCache>>>,
    cache_ttl: Duration,
    http: reqwest::Client,
}

impl AuthService {
    fn new(realm_url: String) -> Self {
        let issuer = realm_url.trim_end_matches('/').to_string();
        Self {
            realm_url: format!("{issuer}/protocol/openid-connect/certs"),
            issuer,
            cache: Arc::new(RwLock::new(None)),
            cache_ttl: Duration::from_secs(300),
            http: reqwest::Client::builder()
                .timeout(Duration::from_secs(5))
                .build()
                .expect("reqwest client builds"),
        }
    }

    async fn jwks(&self) -> Result<HashMap<String, DecodingKey>> {
        if let Some(cache) = self.cache.read().as_ref() {
            if Instant::now() < cache.expires_at {
                return Ok(cache.keys.clone());
            }
        }

        let response: Jwks = self
            .http
            .get(&self.realm_url)
            .send()
            .await
            .context("fetch JWKS")?
            .error_for_status()
            .context("JWKS status")?
            .json()
            .await
            .context("parse JWKS")?;

        let mut decoded = HashMap::new();
        for key in response.keys {
            if let (Some(n), Some(e)) = (key.n.as_deref(), key.e.as_deref()) {
                if let Ok(dk) = DecodingKey::from_rsa_components(n, e) {
                    decoded.insert(key.kid.clone(), dk);
                }
            }
        }

        let cache = JwksCache {
            keys: decoded.clone(),
            expires_at: Instant::now() + self.cache_ttl,
        };
        *self.cache.write() = Some(cache);
        Ok(decoded)
    }

    async fn verify(&self, token: &str) -> Result<Claims> {
        let header = decode_header(token).context("decode header")?;
        let kid = header.kid.ok_or_else(|| anyhow!("missing kid"))?;
        let alg = header.alg;
        let keys = self.jwks().await?;
        let key = keys.get(&kid).ok_or_else(|| anyhow!("unknown kid {kid}"))?;
        let mut validation = Validation::new(if alg == Algorithm::HS256 { Algorithm::RS256 } else { alg });
        validation.set_issuer(&[self.issuer.clone()]);
        validation.validate_aud = false;
        validation.leeway = 30;
        let data = decode::<Claims>(token, key, &validation).context("verify jwt")?;
        Ok(data.claims)
    }
}

#[tonic::async_trait]
impl Authorization for AuthService {
    async fn check(
        &self,
        request: Request<CheckRequest>,
    ) -> Result<Response<CheckResponse>, Status> {
        let attrs = request
            .into_inner()
            .attributes
            .ok_or_else(|| Status::invalid_argument("missing attributes"))?;
        let request_attrs = attrs.request.ok_or_else(|| Status::invalid_argument("no request"))?;
        let http = request_attrs.http.ok_or_else(|| Status::invalid_argument("no http"))?;
        let headers = http.headers;

        let auth = match headers.get("authorization").or_else(|| headers.get("Authorization")) {
            Some(value) => value.clone(),
            None => return Ok(deny("missing Authorization header")),
        };
        let token = match auth.strip_prefix("Bearer ").or_else(|| auth.strip_prefix("bearer ")) {
            Some(t) => t,
            None => return Ok(deny("Authorization is not a Bearer token")),
        };

        match self.verify(token).await {
            Ok(claims) => Ok(allow(&claims)),
            Err(err) => {
                warn!(err = %err, "token rejected");
                Ok(deny(&format!("token rejected: {err}")))
            }
        }
    }
}

fn allow(claims: &Claims) -> Response<CheckResponse> {
    use envoy::config::core::v3::HeaderValue;
    use envoy::config::core::v3::HeaderValueOption;

    let roles = claims.realm_access.roles.join(",");
    let response = CheckResponse {
        status: Some(prost_types::Status {
            code: 0,
            message: String::new(),
            details: vec![],
        }),
        http_response: Some(check_response::HttpResponse::OkResponse(OkHttpResponse {
            headers: vec![
                HeaderValueOption {
                    header: Some(HeaderValue {
                        key: "x-regnant-roles".into(),
                        value: roles,
                        ..Default::default()
                    }),
                    append: None,
                    ..Default::default()
                },
                HeaderValueOption {
                    header: Some(HeaderValue {
                        key: "x-regnant-subject".into(),
                        value: claims.sub.clone(),
                        ..Default::default()
                    }),
                    append: None,
                    ..Default::default()
                },
                HeaderValueOption {
                    header: Some(HeaderValue {
                        key: "x-regnant-user".into(),
                        value: claims.preferred_username.clone(),
                        ..Default::default()
                    }),
                    append: None,
                    ..Default::default()
                },
            ],
            ..Default::default()
        })),
        ..Default::default()
    };
    Response::new(response)
}

fn deny(reason: &str) -> Response<CheckResponse> {
    let response = CheckResponse {
        status: Some(prost_types::Status {
            code: 7,
            message: reason.to_string(),
            details: vec![],
        }),
        http_response: Some(check_response::HttpResponse::DeniedResponse(DeniedHttpResponse {
            status: Some(envoy::r#type::v3::HttpStatus { code: 401 }),
            headers: vec![],
            body: reason.to_string(),
        })),
        ..Default::default()
    };
    Response::new(response)
}

#[tokio::main(flavor = "multi_thread")]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .with_target(false)
        .json()
        .init();

    if std::env::args().nth(1).as_deref() == Some("healthcheck") {
        // Used by docker compose healthcheck.
        return Ok(());
    }

    let addr: SocketAddr = std::env::var("AUTH_LISTEN_ADDR")
        .unwrap_or_else(|_| "0.0.0.0:9191".to_string())
        .parse()
        .context("parse AUTH_LISTEN_ADDR")?;
    let realm_url = std::env::var("KEYCLOAK_REALM_URL")
        .unwrap_or_else(|_| "http://keycloak:8080/realms/regnant".to_string());

    info!(%addr, %realm_url, "starting auth-sidecar");

    let service = AuthService::new(realm_url);
    let server = AuthorizationServer::new(service);

    Server::builder()
        .add_service(server)
        .serve(addr)
        .await
        .map_err(|err| {
            error!(%err, "server error");
            anyhow!(err)
        })?;
    Ok(())
}
