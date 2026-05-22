"""End-to-end tests for the jira-clone backend.

Uses the FastAPI TestClient (no network). The OpenTelemetry exporter
points at a non-existent host; the BatchSpanProcessor swallows export
errors after a short retry, so the tests run cleanly.
"""

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
    body = response.json()
    assert body["status"] == "ok"
    assert "backend" in body


def test_projects_create_and_list(client: TestClient) -> None:
    create = client.post("/projects", json={"key": "REG", "name": "Regnant"})
    assert create.status_code == 201
    project = create.json()
    assert project["key"] == "REG"
    assert project["name"] == "Regnant"

    listed = client.get("/projects")
    assert listed.status_code == 200
    items = listed.json()
    assert any(p["id"] == project["id"] for p in items)


def test_issues_filtered_by_project(client: TestClient) -> None:
    project_id = client.post("/projects", json={"key": "X"}).json()["id"]
    other_project_id = client.post("/projects", json={"key": "Y"}).json()["id"]

    issue = client.post(
        "/issues",
        json={"project_id": project_id, "summary": "foo", "status": "active"},
    ).json()
    client.post("/issues", json={"project_id": other_project_id, "summary": "bar"})

    filtered = client.get(f"/issues?project_id={project_id}").json()
    assert {i["id"] for i in filtered} == {issue["id"]}


def test_issue_rejects_unknown_project(client: TestClient) -> None:
    response = client.post(
        "/issues",
        json={"project_id": "does-not-exist", "summary": "nope"},
    )
    assert response.status_code == 404


def test_sprints_create_and_list(client: TestClient) -> None:
    create = client.post(
        "/sprints",
        json={"project_id": "demo", "name": "Sprint 1", "state": "active"},
    )
    assert create.status_code == 201
    sprint = create.json()
    assert sprint["name"] == "Sprint 1"

    listed = client.get("/sprints").json()
    assert any(s["id"] == sprint["id"] for s in listed)
