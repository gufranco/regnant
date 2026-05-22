//! Ensures every request carries a W3C trace context (`traceparent`)
//! plus a stable `x-request-id`. Generates one when missing.

use proxy_wasm::traits::{Context, HttpContext, RootContext};
use proxy_wasm::types::{Action, ContextType, LogLevel};
use uuid::Uuid;

#[no_mangle]
pub fn _start() {
    proxy_wasm::set_log_level(LogLevel::Info);
    proxy_wasm::set_root_context(|_| -> Box<dyn RootContext> { Box::new(Root) });
}

struct Root;
struct RequestIdInjector;

impl Context for Root {}

impl RootContext for Root {
    fn create_http_context(&self, _: u32) -> Option<Box<dyn HttpContext>> {
        Some(Box::new(RequestIdInjector))
    }

    fn get_type(&self) -> Option<ContextType> {
        Some(ContextType::HttpContext)
    }
}

impl Context for RequestIdInjector {}

impl HttpContext for RequestIdInjector {
    fn on_http_request_headers(&mut self, _: usize, _: bool) -> Action {
        if self.get_http_request_header("x-request-id").is_none() {
            let request_id = Uuid::new_v4().to_string();
            self.set_http_request_header("x-request-id", Some(&request_id));
        }
        if self.get_http_request_header("traceparent").is_none() {
            // 00-<trace_id_32>-<span_id_16>-01
            let trace_id = uuid_hex(32);
            let span_id = uuid_hex(16);
            let header = format!("00-{trace_id}-{span_id}-01");
            self.set_http_request_header("traceparent", Some(&header));
        }
        Action::Continue
    }

    fn on_http_response_headers(&mut self, _: usize, _: bool) -> Action {
        if let Some(rid) = self.get_http_request_header("x-request-id") {
            self.set_http_response_header("x-request-id", Some(&rid));
        }
        Action::Continue
    }
}

fn uuid_hex(width: usize) -> String {
    let mut buf = String::with_capacity(width);
    while buf.len() < width {
        buf.push_str(&Uuid::new_v4().simple().to_string());
    }
    buf.truncate(width);
    buf
}
