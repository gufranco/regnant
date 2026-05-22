//! Deterministic A/B router. JSON config:
//! `{"split_header": "x-ab-key", "weight": 50, "cluster_a": "...", "cluster_b": "..."}`.

use std::sync::Arc;

use proxy_wasm::traits::{Context, HttpContext, RootContext};
use proxy_wasm::types::{Action, ContextType, LogLevel};
use serde::Deserialize;
use xxhash_rust::xxh3::xxh3_64;

#[derive(Debug, Deserialize)]
struct Config {
    #[serde(default = "default_header")]
    split_header: String,
    #[serde(default = "default_weight")]
    weight: u32,
    #[serde(default = "default_cluster_a")]
    cluster_a: String,
    #[serde(default = "default_cluster_b")]
    cluster_b: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            split_header: default_header(),
            weight: default_weight(),
            cluster_a: default_cluster_a(),
            cluster_b: default_cluster_b(),
        }
    }
}

fn default_header() -> String {
    "x-ab-key".into()
}

fn default_weight() -> u32 {
    50
}

fn default_cluster_a() -> String {
    "regnant_a".into()
}

fn default_cluster_b() -> String {
    "regnant_b".into()
}

#[derive(Default)]
struct Root {
    config: Arc<Config>,
}

struct AbRouter {
    config: Arc<Config>,
}

#[no_mangle]
pub fn _start() {
    proxy_wasm::set_log_level(LogLevel::Info);
    proxy_wasm::set_root_context(|_| -> Box<dyn RootContext> { Box::<Root>::default() });
}

impl Context for Root {}

impl RootContext for Root {
    fn on_configure(&mut self, _: usize) -> bool {
        if let Some(bytes) = self.get_plugin_configuration() {
            match serde_json::from_slice::<Config>(&bytes) {
                Ok(parsed) => self.config = Arc::new(parsed),
                Err(err) => log::warn!("ab_router: invalid configuration: {err}"),
            }
        }
        true
    }

    fn create_http_context(&self, _: u32) -> Option<Box<dyn HttpContext>> {
        Some(Box::new(AbRouter {
            config: Arc::clone(&self.config),
        }))
    }

    fn get_type(&self) -> Option<ContextType> {
        Some(ContextType::HttpContext)
    }
}

impl Context for AbRouter {}

impl HttpContext for AbRouter {
    fn on_http_request_headers(&mut self, _: usize, _: bool) -> Action {
        let key = self
            .get_http_request_header(&self.config.split_header)
            .unwrap_or_else(|| {
                self.get_http_request_header(":authority")
                    .unwrap_or_else(|| "anon".into())
            });
        let bucket = (xxh3_64(key.as_bytes()) % 100) as u32;
        let target = if bucket < self.config.weight {
            &self.config.cluster_a
        } else {
            &self.config.cluster_b
        };
        self.set_http_request_header("x-regnant-cluster", Some(target));
        Action::Continue
    }
}
