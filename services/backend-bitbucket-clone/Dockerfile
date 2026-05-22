ARG PYTHON_VERSION=3.13-slim-bookworm

FROM python:${PYTHON_VERSION} AS builder

ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install --yes --no-install-recommends build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY pyproject.toml ./
COPY app ./app
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --upgrade pip wheel \
    && /opt/venv/bin/pip install .

FROM gcr.io/distroless/python3-debian12:nonroot

ENV PATH="/opt/venv/bin:${PATH}" PYTHONUNBUFFERED=1

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /build/app /app/app

WORKDIR /app
USER nonroot
EXPOSE 8080
ENTRYPOINT ["/opt/venv/bin/python", "-m", "app.main"]
