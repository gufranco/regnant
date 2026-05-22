FROM rust:1.83-bookworm AS builder

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install --yes --no-install-recommends protobuf-compiler ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY Cargo.toml Cargo.lock* ./
COPY build.rs ./
COPY src ./src
COPY proto ./proto

RUN cargo build --release --locked

FROM gcr.io/distroless/cc-debian12:nonroot

COPY --from=builder /build/target/release/auth-sidecar /auth-sidecar

USER nonroot
EXPOSE 9191
ENTRYPOINT ["/auth-sidecar"]
