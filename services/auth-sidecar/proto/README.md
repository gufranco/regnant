# Envoy protobuf vendor tree

This directory mirrors the subset of the Envoy data-plane-api repo that
the auth-sidecar's build.rs compiles via tonic-build. Vendoring keeps
builds reproducible and works in air-gapped CI runners.

Populate at build time with:

```bash
git clone --depth 1 https://github.com/envoyproxy/data-plane-api proto
```

or sync only the files the build needs:

```
proto/envoy/service/auth/v3/external_auth.proto
proto/envoy/service/auth/v3/attribute_context.proto
proto/envoy/config/core/v3/base.proto
proto/envoy/type/v3/http_status.proto
proto/envoy/type/matcher/v3/string.proto
proto/google/rpc/status.proto
proto/validate/validate.proto
```

The .gitignore excludes the unpacked tree; only this README is tracked.
