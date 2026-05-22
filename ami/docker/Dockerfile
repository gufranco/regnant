# Runtime mirror of the Packer-built AMI. Builds the same Envoy +
# OTel-agent payload as a Docker image for use by the envoy-* compose
# services. Multi-stage so the final image is minimal.

ARG ENVOY_VERSION=v1.34.1
ARG OTEL_VERSION=0.115.1

FROM debian:12-slim AS builder

ARG ENVOY_VERSION
ARG OTEL_VERSION

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/build

RUN ARCH="$(dpkg --print-architecture)" \
    && case "$ARCH" in \
        amd64) ENVOY_ARCH=amd64; GO_ARCH=amd64 ;; \
        arm64) ENVOY_ARCH=arm64; GO_ARCH=arm64 ;; \
        *) echo "unsupported arch $ARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/tetratelabs/archive-envoy/releases/download/${ENVOY_VERSION}/envoy-${ENVOY_VERSION}-linux-${ENVOY_ARCH}.tar.xz" -o /tmp/envoy.tar.xz \
    && tar -xJf /tmp/envoy.tar.xz -C /tmp \
    && cp "$(find /tmp -maxdepth 4 -type f -name envoy | head -n1)" /opt/build/envoy \
    && chmod +x /opt/build/envoy \
    && curl -fsSL "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol-contrib_${OTEL_VERSION}_linux_${GO_ARCH}.tar.gz" -o /tmp/otelcol.tgz \
    && tar -xzf /tmp/otelcol.tgz -C /tmp \
    && cp /tmp/otelcol-contrib /opt/build/otelcol-contrib \
    && chmod +x /opt/build/otelcol-contrib \
    && rm -rf /tmp/envoy.tar.xz /tmp/otelcol.tgz

FROM gcr.io/distroless/cc-debian12:nonroot

LABEL org.opencontainers.image.title="regnant envoy fleet" \
      org.opencontainers.image.source="https://github.com/gufranco/regnant" \
      org.opencontainers.image.licenses="Apache-2.0"

USER 65532:65532
WORKDIR /etc/envoy

COPY --from=builder --chown=65532:65532 /opt/build/envoy /usr/local/bin/envoy
COPY --from=builder --chown=65532:65532 /opt/build/otelcol-contrib /usr/local/bin/otelcol-contrib

COPY --chown=65532:65532 envoy/bootstrap.yaml.tmpl /etc/envoy/bootstrap.yaml.tmpl

EXPOSE 9901 10000 443

ENTRYPOINT ["/usr/local/bin/envoy"]
CMD ["--config-path", "/etc/envoy/bootstrap.yaml"]
