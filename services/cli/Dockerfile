FROM rust:1.90-bookworm AS builder

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY Cargo.toml Cargo.lock* ./
COPY src ./src

RUN cargo build --release --locked

FROM gcr.io/distroless/cc-debian12:nonroot

COPY --from=builder /build/target/release/regnant /usr/local/bin/regnant

USER nonroot
ENTRYPOINT ["/usr/local/bin/regnant"]
