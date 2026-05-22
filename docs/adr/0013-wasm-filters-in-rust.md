# ADR-0013: WASM filters in Rust

**Status:** accepted
**Date:** 2026-05-22

## Context

The videos describe Envoy extensions as a place where centralized
logic lived (header rewriting, A/B routing, request-id injection).

## Decision

Three Rust crates compiled to `wasm32-wasi` via the upstream
`proxy-wasm-rust-sdk`: `header-rewriter`, `ab-router`,
`request-id-injector`. Sovereign's `extension_configs` template
references them; Envoy loads them via `envoy.filters.http.wasm`.

## Alternatives Considered

### Native Envoy filters in C++

Pros: lowest latency.
Cons: every change forces a new Envoy build. Loses the WASM
deployability story.

### Lua filters

Pros: built-in, no extra toolchain.
Cons: not the language the source material uses; less testable.

## Consequences

### Positive

- The deployment unit is a .wasm artifact, easy to ship and rotate.
- Identical filters can be loaded into other proxies that speak
  proxy-wasm (e.g., Istio).

### Negative

- WASM has its own debugging surface; stack traces are uglier than
  native Rust.
- Cold-start cost on first request after a config push.

### Risks

- proxy-wasm-rust-sdk API churn breaks filters on Envoy upgrades.
  Mitigation: pin both crate and Envoy versions; CI matrix on the
  Envoy upgrade PR.
