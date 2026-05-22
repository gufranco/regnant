"""S3-backed context plugin for Sovereign.

Reads every YAML object under the configured prefix, parses them, and
exposes the union as the `artifacts` template context. The OSB worker
writes these artifacts when a new service instance is provisioned.
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any

import boto3
import structlog
import yaml
from botocore.config import Config

logger = structlog.get_logger(__name__)


@dataclass
class _Cache:
    payload: dict[str, Any]
    fetched_at: float


class S3ContextPlugin:
    """Sovereign-pluggable context loader."""

    def __init__(self, *, config: dict[str, Any]) -> None:
        self._bucket = config["bucket"]
        self._prefix = config.get("prefix", "envoy-resources/")
        self._refresh_interval = int(config.get("refresh_interval", 30))
        self._endpoint_url = config.get("endpoint_url")
        self._region = config.get("region", "us-east-1")
        self._client = boto3.client(
            "s3",
            endpoint_url=self._endpoint_url,
            region_name=self._region,
            config=Config(retries={"max_attempts": 8, "mode": "standard"}),
        )
        self._cache: _Cache | None = None

    def __call__(self) -> dict[str, Any]:
        now = time.time()
        if self._cache and now - self._cache.fetched_at < self._refresh_interval:
            return self._cache.payload

        artifacts: dict[str, Any] = {}
        continuation_token: str | None = None
        while True:
            kwargs: dict[str, Any] = {"Bucket": self._bucket, "Prefix": self._prefix}
            if continuation_token:
                kwargs["ContinuationToken"] = continuation_token
            response = self._client.list_objects_v2(**kwargs)
            for obj in response.get("Contents", []):
                key = obj["Key"]
                if not key.endswith(".yaml"):
                    continue
                body = self._client.get_object(Bucket=self._bucket, Key=key)["Body"].read()
                try:
                    artifacts[key] = yaml.safe_load(body)
                except yaml.YAMLError as exc:
                    logger.warning("malformed artifact", key=key, err=str(exc))
            if not response.get("IsTruncated"):
                break
            continuation_token = response.get("NextContinuationToken")

        self._cache = _Cache(payload=artifacts, fetched_at=now)
        return artifacts


def create(config: dict[str, Any]) -> S3ContextPlugin:
    """Sovereign entrypoint used by the YAML config block."""
    return S3ContextPlugin(config=config)
