"""Runtime configuration loaded from environment."""

from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """All knobs the OSB API and worker read at startup."""

    model_config = SettingsConfigDict(env_prefix="OSB_", extra="ignore")

    aws_endpoint_url: str = Field(default="http://localstack:4566", alias="AWS_ENDPOINT_URL")
    aws_region: str = Field(default="us-east-1", alias="AWS_DEFAULT_REGION")
    aws_access_key_id: str = Field(default="test", alias="AWS_ACCESS_KEY_ID")
    aws_secret_access_key: str = Field(default="test", alias="AWS_SECRET_ACCESS_KEY")

    broker_username: str = Field(default="broker", alias="OSB_BROKER_USERNAME")
    broker_password: str = Field(default="changeme", alias="OSB_BROKER_PASSWORD")

    artifact_bucket: str = "regnant-osb-artifacts"
    artifact_prefix: str = "envoy-resources/"
    instances_table: str = "regnant-service-instances"
    bindings_table: str = "regnant-service-bindings"
    provision_queue_url: str = "http://localstack:4566/000000000000/regnant-provision-tasks"
    binding_queue_url: str = "http://localstack:4566/000000000000/regnant-binding-tasks"

    otel_endpoint: str = Field(
        default="http://otel-collector:4317", alias="OTEL_EXPORTER_OTLP_ENDPOINT"
    )
    otel_service_name: str = Field(default="osb-api", alias="OTEL_SERVICE_NAME")
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")

    host: str = "0.0.0.0"
    port: int = 8080

    worker_poll_seconds: int = 20
    worker_max_messages: int = 5
    worker_visibility_seconds: int = 90


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Cached settings accessor."""
    return Settings()
