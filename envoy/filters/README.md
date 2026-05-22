# WASM filters

Three Envoy HTTP filters built with `proxy-wasm-rust-sdk` and compiled
to `wasm32-wasi`. Loaded by Envoy via `envoy.filters.http.wasm` and
referenced from Sovereign's `extension_configs` template.

## Filters

| Crate | Behavior |
|-------|----------|
| `header-rewriter` | Add/remove response headers per a JSON config |
| `ab-router` | Deterministic A/B split by hashing a configurable request header (default `x-ab-key`); sets `x-regnant-cluster` |
| `request-id-injector` | Ensures every request has a W3C `traceparent` and a stable `x-request-id`; copies the request-id back into the response |

## Build

Each filter has its own Cargo manifest. Build all three:

```bash
for f in header-rewriter ab-router request-id-injector; do
  cargo build --release --target wasm32-wasi --manifest-path "envoy/filters/$f/Cargo.toml"
done
```

The resulting `.wasm` artifacts under
`target/wasm32-wasi/release/regnant_*.wasm` are mounted into the Envoy
container at `/etc/envoy/filters/`.

## Test

```bash
cargo test --manifest-path envoy/filters/<name>/Cargo.toml
```

The build pipeline (CI) compiles for wasm32-wasi and runs filter
tests against an Envoy harness.
