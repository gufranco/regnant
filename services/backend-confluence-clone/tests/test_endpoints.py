"""End-to-end tests for the confluence-clone backend."""

from __future__ import annotations

import os

os.environ.setdefault("OTEL_EXPORTER_OTLP_ENDPOINT", "http://127.0.0.1:1")

import pytest
from app.main import _make_app
from fastapi.testclient import TestClient


@pytest.fixture
def client() -> TestClient:
    return TestClient(_make_app())


def test_health(client: TestClient) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_spaces_create_and_list(client: TestClient) -> None:
    create = client.post("/spaces", json={"key": "ENG", "name": "Engineering"})
    assert create.status_code == 201
    space = create.json()
    assert space["key"] == "ENG"

    listed = client.get("/spaces").json()
    assert any(s["id"] == space["id"] for s in listed)


def test_pages_filtered_by_space(client: TestClient) -> None:
    space_id = client.post("/spaces", json={"key": "A"}).json()["id"]
    other_space_id = client.post("/spaces", json={"key": "B"}).json()["id"]
    page = client.post(
        "/pages",
        json={"space_id": space_id, "title": "Onboarding", "content": "hi"},
    ).json()
    client.post("/pages", json={"space_id": other_space_id, "title": "Off-topic"})

    filtered = client.get(f"/pages?space_id={space_id}").json()
    assert {p["id"] for p in filtered} == {page["id"]}


def test_pages_reject_unknown_space(client: TestClient) -> None:
    response = client.post(
        "/pages",
        json={"space_id": "does-not-exist", "title": "Nope"},
    )
    assert response.status_code == 404


def test_labels(client: TestClient) -> None:
    label = client.post("/labels", json={"name": "urgent", "color": "#f00"}).json()
    listed = client.get("/labels").json()
    assert any(item["id"] == label["id"] for item in listed)
