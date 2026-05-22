# Multi-stage build: install deps with pip-compile-equivalent in a
# fat image, copy the resolved tree into a distroless final stage.

# hadolint global ignore=DL3008,DL3018
ARG PYTHON_VERSION=3.13-slim-bookworm

FROM python:${PYTHON_VERSION} AS builder

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY pyproject.toml README.md ./
COPY osb ./osb
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --upgrade pip wheel \
    && /opt/venv/bin/pip install .

FROM gcr.io/distroless/python3-debian12:nonroot AS api

ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /build/osb /app/osb

WORKDIR /app
USER nonroot
EXPOSE 8080
ENTRYPOINT ["/opt/venv/bin/python", "-m", "osb.api.main"]

FROM gcr.io/distroless/python3-debian12:nonroot AS worker

ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /build/osb /app/osb

WORKDIR /app
USER nonroot
ENTRYPOINT ["/opt/venv/bin/python", "-m", "osb.worker.main"]
