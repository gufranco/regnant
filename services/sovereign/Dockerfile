ARG PYTHON_VERSION=3.13-slim-bookworm

FROM python:${PYTHON_VERSION} AS builder

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --upgrade pip wheel \
    && /opt/venv/bin/pip install \
        "sovereign==0.32.8" \
        "boto3>=1.35.0" \
        "structlog>=24.4.0" \
        "redis<=5.0.0" \
        "opentelemetry-api>=1.28.0" \
        "opentelemetry-sdk>=1.28.0" \
        "opentelemetry-exporter-otlp-proto-grpc>=1.28.0"

FROM gcr.io/distroless/python3-debian12:nonroot

ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1 \
    SOVEREIGN_CONFIG=/etc/sovereign/config.yaml

COPY --from=builder /opt/venv /opt/venv
COPY config.yaml /etc/sovereign/config.yaml
COPY templates /etc/sovereign/templates
COPY plugins /etc/sovereign/plugins

WORKDIR /etc/sovereign
USER nonroot
EXPOSE 8080
ENTRYPOINT ["/opt/venv/bin/python", "-m", "uvicorn", "sovereign.app:app", "--host", "0.0.0.0", "--port", "8080"]
