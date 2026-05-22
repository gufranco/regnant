# regnant Rust SDK

The CLI's `src/broker.rs` is the Rust SDK in this revision: a thin
typed wrapper over the OSB HTTP surface. When the project needs the
SDK separate from the CLI, generate it from the OpenAPI spec:

```bash
cargo install openapi-generator-cli
openapi-generator-cli generate \
  --input-spec ../../osb/openapi.yaml \
  --generator-name rust \
  --output .
```

The generated crate replaces this README. The CLI then depends on it
via a path dependency instead of inlining the broker module.

Keeping the CLI's broker module as the SDK avoids a duplicate
maintenance burden while the surface is small.
