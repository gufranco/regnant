"""Catalog endpoint behavior."""

from __future__ import annotations

from fastapi.testclient import TestClient

from osb.api.main import create_app


def test_catalog_returns_three_services(
    dynamodb_tables: dict[str, str],
    sqs_queues: dict[str, str],
    s3_bucket: str,
) -> None:
    # Arrange
    client = TestClient(create_app())

    # Act
    response = client.get(
        "/v2/catalog",
        auth=("broker", "test-pass"),
        headers={"X-Broker-API-Version": "2.16"},
    )

    # Assert
    assert response.status_code == 200
    body = response.json()
    assert {s["id"] for s in body["services"]} == {
        "regnant-lb-basic",
        "regnant-lb-pro",
        "regnant-lb-edge",
    }
    for service in body["services"]:
        assert len(service["plans"]) == 2


def test_catalog_requires_basic_auth(
    dynamodb_tables: dict[str, str],
    sqs_queues: dict[str, str],
    s3_bucket: str,
) -> None:
    # Arrange
    client = TestClient(create_app())

    # Act
    response = client.get("/v2/catalog")

    # Assert
    assert response.status_code == 401
    assert response.headers.get("www-authenticate", "").lower().startswith("basic")


def test_catalog_rejects_wrong_password(
    dynamodb_tables: dict[str, str],
    sqs_queues: dict[str, str],
    s3_bucket: str,
) -> None:
    # Arrange
    client = TestClient(create_app())

    # Act
    response = client.get("/v2/catalog", auth=("broker", "wrong"))

    # Assert
    assert response.status_code == 401
