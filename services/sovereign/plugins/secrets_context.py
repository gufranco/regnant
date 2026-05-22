"""Secrets Manager context plugin: streams every leaf bundle under the
project prefix into the Sovereign template context as `secrets`."""

from __future__ import annotations

import json
import time
from dataclasses import dataclass
from typing import Any

import boto3
import structlog
from botocore.config import Config

logger = structlog.get_logger(__name__)


@dataclass
class _Cache:
    payload: dict[str, dict[str, str]]
    fetched_at: float


class SecretsContextPlugin:
    """Sovereign-pluggable context loader for AWS Secrets Manager."""

    def __init__(self, *, config: dict[str, Any]) -> None:
        self._prefix = config.get("prefix", "regnant/")
        self._refresh_interval = int(config.get("refresh_interval", 60))
        self._endpoint_url = config.get("endpoint_url")
        self._region = config.get("region", "us-east-1")
        self._client = boto3.client(
            "secretsmanager",
            endpoint_url=self._endpoint_url,
            region_name=self._region,
            config=Config(retries={"max_attempts": 8, "mode": "standard"}),
        )
        self._cache: _Cache | None = None

    def __call__(self) -> dict[str, dict[str, str]]:
        now = time.time()
        if self._cache and now - self._cache.fetched_at < self._refresh_interval:
            return self._cache.payload

        secrets: dict[str, dict[str, str]] = {}
        token: str | None = None
        while True:
            kwargs: dict[str, Any] = {
                "Filters": [{"Key": "name", "Values": [self._prefix]}],
                "MaxResults": 100,
            }
            if token:
                kwargs["NextToken"] = token
            response = self._client.list_secrets(**kwargs)
            for entry in response.get("SecretList", []):
                name = entry["Name"]
                if not name.startswith(f"{self._prefix}leaf/"):
                    continue
                key = name[len(f"{self._prefix}leaf/"):]
                try:
                    payload = self._client.get_secret_value(SecretId=name)["SecretString"]
                    secrets[key] = json.loads(payload)
                except (self._client.exceptions.ResourceNotFoundException, json.JSONDecodeError) as exc:
                    logger.warning("could not read secret", name=name, err=str(exc))
            token = response.get("NextToken")
            if not token:
                break

        self._cache = _Cache(payload=secrets, fetched_at=now)
        return secrets


def create(config: dict[str, Any]) -> SecretsContextPlugin:
    return SecretsContextPlugin(config=config)
