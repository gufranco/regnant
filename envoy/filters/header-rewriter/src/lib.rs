//! Response header rewriter. JSON config: `{"add": {"name": "value"}, "remove": ["name"]}`.

use std::collections::HashMap;
use std::sync::Arc;

use proxy_wasm::traits::{Context, HttpContext, RootContext};
use proxy_wasm::types::{Action, ContextType, LogLevel};
use serde::Deserialize;

#[derive(Debug, Default, Deserialize)]
struct Config {
    #[serde(default)]
    add: HashMap<String, String>,
    #[serde(default)]
    remove: Vec<String>,
}

#[derive(Default)]
struct Root {
    config: Arc<Config>,
}

#[derive(Default)]
struct HeaderRewriter {
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
                Ok(parsed) => {
                    self.config = Arc::new(parsed);
                }
                Err(err) => {
                    log::warn!("header_rewriter: invalid configuration: {err}");
                }
            }
        }
        true
    }

    fn create_http_context(&self, _: u32) -> Option<Box<dyn HttpContext>> {
        Some(Box::new(HeaderRewriter {
            config: Arc::clone(&self.config),
        }))
    }

    fn get_type(&self) -> Option<ContextType> {
        Some(ContextType::HttpContext)
    }
}

impl Context for HeaderRewriter {}

impl HttpContext for HeaderRewriter {
    fn on_http_response_headers(&mut self, _: usize, _: bool) -> Action {
        for name in &self.config.remove {
            self.set_http_response_header(name, None);
        }
        for (name, value) in &self.config.add {
            self.set_http_response_header(name, Some(value));
        }
        Action::Continue
    }
}
