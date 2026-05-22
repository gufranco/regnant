"""Provisioning flow: PUT -> SQS message -> DDB row -> GET last_operation."""

from __future__ import annotations

import json

import boto3
from faker import Faker
from fastapi.testclient import TestClient

from osb.api.main import create_app


def test_provision_creates_instance_and_enqueues(
    dynamodb_tables: dict[str, str],
    sqs_queues: dict[str, str],
    s3_bucket: str,
    moto_server: str,
    faker_session: Faker,
) -> None:
    # Arrange
    client = TestClient(create_app())
    instance_id = faker_session.uuid4()
    payload = {
        "service_id": "regnant-lb-pro",
        "plan_id": "regnant-lb-pro-single",
        "context": {"platform": "regnant"},
        "parameters": {"upstream": {"host": "backend-jira-clone", "port": 8080}},
    }

    # Act
    response = client.put(
        f"/v2/service_instances/{instance_id}?accepts_incomplete=true",
        auth=("broker", "test-pass"),
        json=payload,
    )

    # Assert
    assert response.status_code == 202
    body = response.json()
    assert body["operation"] == "provision"

    ddb = boto3.client("dynamodb", endpoint_url=moto_server, region_name="us-east-1")
    record = ddb.get_item(
        TableName=dynamodb_tables["instances"],
        Key={"instance_id": {"S": instance_id}},
    )
    assert record["Item"]["state"]["S"] == "provisioning"

    sqs = boto3.client("sqs", endpoint_url=moto_server, region_name="us-east-1")
    msg = sqs.receive_message(QueueUrl=sqs_queues["provision"], MaxNumberOfMessages=1, WaitTimeSeconds=1)
    assert "Messages" in msg
    queued = json.loads(msg["Messages"][0]["Body"])
    assert queued == {"op": "provision", "instance_id": instance_id, **payload}


def test_provision_requires_async(
    dynamodb_tables: dict[str, str],
    sqs_queues: dict[str, str],
    s3_bucket: str,
    faker_session: Faker,
) -> None:
    # Arrange
    client = TestClient(create_app())
    instance_id = faker_session.uuid4()

    # Act
    response = client.put(
        f"/v2/service_instances/{instance_id}",
        auth=("broker", "test-pass"),
        json={"service_id": "regnant-lb-pro", "plan_id": "regnant-lb-pro-single"},
    )

    # Assert
    assert response.status_code == 422
    assert response.json()["error"] == "AsyncRequired"


def test_provision_idempotent_on_same_params(
    dynamodb_tables: dict[str, str],
    sqs_queues: dict[str, str],
    s3_bucket: str,
    faker_session: Faker,
) -> None:
    # Arrange
    client = TestClient(create_app())
    instance_id = faker_session.uuid4()
    payload = {"service_id": "regnant-lb-pro", "plan_id": "regnant-lb-pro-single"}

    # Act
    first = client.put(
        f"/v2/service_instances/{instance_id}?accepts_incomplete=true",
        auth=("broker", "test-pass"),
        json=payload,
    )
    second = client.put(
        f"/v2/service_instances/{instance_id}?accepts_incomplete=true",
        auth=("broker", "test-pass"),
        json=payload,
    )

    # Assert
    assert first.status_code == 202
    assert second.status_code == 202


def test_provision_conflicts_on_different_params(
    dynamodb_tables: dict[str, str],
    sqs_queues: dict[str, str],
    s3_bucket: str,
    faker_session: Faker,
) -> None:
    # Arrange
    client = TestClient(create_app())
    instance_id = faker_session.uuid4()
    first_payload = {"service_id": "regnant-lb-pro", "plan_id": "regnant-lb-pro-single"}
    second_payload = {"service_id": "regnant-lb-edge", "plan_id": "regnant-lb-edge-single"}

    # Act
    client.put(
        f"/v2/service_instances/{instance_id}?accepts_incomplete=true",
        auth=("broker", "test-pass"),
        json=first_payload,
    )
    response = client.put(
        f"/v2/service_instances/{instance_id}?accepts_incomplete=true",
        auth=("broker", "test-pass"),
        json=second_payload,
    )

    # Assert
    assert response.status_code == 409
