"""Shared test fixtures. Boots an in-process moto server so the storage
layer talks to a real (mocked) AWS surface."""

from __future__ import annotations

import os
import socket
import threading
import time
from collections.abc import Iterator

import boto3
import pytest
from faker import Faker
from moto.server import ThreadedMotoServer


@pytest.fixture(scope="session")
def moto_server() -> Iterator[str]:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        port = s.getsockname()[1]
    server = ThreadedMotoServer(port=port)
    thread = threading.Thread(target=server.start, daemon=True)
    thread.start()
    endpoint = f"http://127.0.0.1:{port}"
    # wait for the server to bind
    for _ in range(50):
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.1):
                break
        except OSError:
            time.sleep(0.05)
    yield endpoint
    server.stop()


@pytest.fixture(scope="session")
def faker_session() -> Faker:
    fake = Faker()
    Faker.seed(20260522)
    return fake


@pytest.fixture(autouse=True)
def aws_env(moto_server: str, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("AWS_ENDPOINT_URL", moto_server)
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "test")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "test")  # noqa: S105
    monkeypatch.setenv("OSB_BROKER_USERNAME", "broker")
    monkeypatch.setenv("OSB_BROKER_PASSWORD", "test-pass")
    monkeypatch.setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://127.0.0.1:0")

    # Reset cached settings between tests.
    from osb import config

    config.get_settings.cache_clear()


@pytest.fixture
def s3_bucket(moto_server: str) -> str:
    bucket = "regnant-osb-artifacts"
    client = boto3.client("s3", endpoint_url=moto_server, region_name="us-east-1")
    client.create_bucket(Bucket=bucket)
    return bucket


@pytest.fixture
def dynamodb_tables(moto_server: str) -> dict[str, str]:
    client = boto3.client("dynamodb", endpoint_url=moto_server, region_name="us-east-1")
    instances = "regnant-service-instances"
    bindings = "regnant-service-bindings"
    client.create_table(
        TableName=instances,
        AttributeDefinitions=[
            {"AttributeName": "instance_id", "AttributeType": "S"},
            {"AttributeName": "state", "AttributeType": "S"},
        ],
        KeySchema=[{"AttributeName": "instance_id", "KeyType": "HASH"}],
        BillingMode="PAY_PER_REQUEST",
        GlobalSecondaryIndexes=[
            {
                "IndexName": "by-state",
                "KeySchema": [{"AttributeName": "state", "KeyType": "HASH"}],
                "Projection": {"ProjectionType": "ALL"},
            },
        ],
    )
    client.create_table(
        TableName=bindings,
        AttributeDefinitions=[
            {"AttributeName": "binding_id", "AttributeType": "S"},
            {"AttributeName": "instance_id", "AttributeType": "S"},
        ],
        KeySchema=[
            {"AttributeName": "binding_id", "KeyType": "HASH"},
            {"AttributeName": "instance_id", "KeyType": "RANGE"},
        ],
        BillingMode="PAY_PER_REQUEST",
    )
    return {"instances": instances, "bindings": bindings}


@pytest.fixture
def sqs_queues(moto_server: str) -> dict[str, str]:
    client = boto3.client("sqs", endpoint_url=moto_server, region_name="us-east-1")
    provision = client.create_queue(QueueName="regnant-provision-tasks")["QueueUrl"]
    binding = client.create_queue(QueueName="regnant-binding-tasks")["QueueUrl"]
    os.environ["OSB_PROVISION_QUEUE_URL"] = provision
    os.environ["OSB_BINDING_QUEUE_URL"] = binding
    return {"provision": provision, "binding": binding}
