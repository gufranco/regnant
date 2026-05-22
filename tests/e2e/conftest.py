"""Shared E2E fixtures. Assume the compose stack is up via `make bootstrap`."""

from __future__ import annotations

import os
import uuid
from collections.abc import Iterator

import boto3
import httpx
import pytest
from faker import Faker


def _endpoint(name: str, default: str) -> str:
    return os.getenv(name, default)


@pytest.fixture(scope="session")
def localstack_endpoint() -> str:
    return _endpoint("AWS_ENDPOINT_URL", "http://localhost:4566")


@pytest.fixture(scope="session")
def osb_url() -> str:
    return _endpoint("OSB_URL", "http://localhost:8080")


@pytest.fixture(scope="session")
def sovereign_url() -> str:
    return _endpoint("SOVEREIGN_URL", "http://localhost:8000")


@pytest.fixture(scope="session")
def keycloak_url() -> str:
    return _endpoint("KEYCLOAK_URL", "http://localhost:8090")


@pytest.fixture(scope="session")
def envoy_url() -> str:
    return _endpoint("ENVOY_URL", "https://localhost:8443")


@pytest.fixture(scope="session")
def osb_credentials() -> tuple[str, str]:
    return (
        os.getenv("OSB_BROKER_USERNAME", "broker"),
        os.getenv("OSB_BROKER_PASSWORD", "changeme"),
    )


@pytest.fixture(scope="session")
def faker_seeded() -> Faker:
    fake = Faker()
    Faker.seed(20260522)
    return fake


@pytest.fixture
def osb_client(osb_url: str, osb_credentials: tuple[str, str]) -> Iterator[httpx.Client]:
    with httpx.Client(
        base_url=osb_url,
        auth=osb_credentials,
        headers={"X-Broker-API-Version": "2.16"},
        timeout=10.0,
    ) as client:
        yield client


@pytest.fixture
def envoy_client(envoy_url: str) -> Iterator[httpx.Client]:
    with httpx.Client(base_url=envoy_url, verify=False, timeout=10.0) as client:
        yield client


@pytest.fixture
def s3_client(localstack_endpoint: str):
    return boto3.client(
        "s3",
        endpoint_url=localstack_endpoint,
        region_name="us-east-1",
        aws_access_key_id="test",
        aws_secret_access_key="test",  # noqa: S106
    )


@pytest.fixture
def dynamodb_client(localstack_endpoint: str):
    return boto3.client(
        "dynamodb",
        endpoint_url=localstack_endpoint,
        region_name="us-east-1",
        aws_access_key_id="test",
        aws_secret_access_key="test",  # noqa: S106
    )


@pytest.fixture
def instance_id() -> str:
    return str(uuid.uuid4())


@pytest.fixture
def binding_id() -> str:
    return str(uuid.uuid4())
