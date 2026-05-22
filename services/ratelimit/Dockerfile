FROM rust:1.83-bookworm AS builder

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install --yes --no-install-recommends git protobuf-compiler ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
ARG STEWARD_REF=main
# hadolint ignore=DL3003
RUN git clone --depth 1 --branch "$STEWARD_REF" https://github.com/cetanu/steward.git \
    && cd steward \
    && cargo build --release --locked

FROM gcr.io/distroless/cc-debian12:nonroot

COPY --from=builder /build/steward/target/release/steward /usr/local/bin/steward
COPY config /data/ratelimit/config

USER nonroot
EXPOSE 8081
ENV RUNTIME_ROOT=/data \
    RUNTIME_SUBDIRECTORY=ratelimit \
    USE_STATSD=false \
    LOG_LEVEL=info

ENTRYPOINT ["/usr/local/bin/steward"]
