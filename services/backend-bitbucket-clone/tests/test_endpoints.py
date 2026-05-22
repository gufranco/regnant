"""End-to-end tests for the bitbucket-clone backend."""

from __future__ import annotations

import os

os.environ.setdefault("OTEL_EXPORTER_OTLP_ENDPOINT", "http://127.0.0.1:1")

import pytest
from fastapi.testclient import TestClient

from app.main import _make_app


@pytest.fixture
def client() -> TestClient:
    return TestClient(_make_app())


def test_health(client: TestClient) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_repos_create_and_list(client: TestClient) -> None:
    create = client.post(
        "/repos",
        json={"workspace": "regnant", "slug": "core", "default_branch": "main"},
    )
    assert create.status_code == 201
    repo = create.json()
    assert repo["slug"] == "core"

    listed = client.get("/repos").json()
    assert any(item["id"] == repo["id"] for item in listed)


def test_pullrequests_filtered_by_repo(client: TestClient) -> None:
    repo_id = client.post("/repos", json={"slug": "a"}).json()["id"]
    other_repo_id = client.post("/repos", json={"slug": "b"}).json()["id"]
    pull_request = client.post(
        "/pullrequests",
        json={
            "repo_id": repo_id,
            "title": "Add tests",
            "source_branch": "feat/tests",
            "target_branch": "main",
        },
    ).json()
    client.post(
        "/pullrequests",
        json={"repo_id": other_repo_id, "title": "Off"},
    )

    filtered = client.get(f"/pullrequests?repo_id={repo_id}").json()
    assert {pr["id"] for pr in filtered} == {pull_request["id"]}


def test_pullrequests_reject_unknown_repo(client: TestClient) -> None:
    response = client.post(
        "/pullrequests",
        json={"repo_id": "does-not-exist", "title": "Nope"},
    )
    assert response.status_code == 404


def test_branches(client: TestClient) -> None:
    repo_id = client.post("/repos", json={"slug": "c"}).json()["id"]
    branch = client.post(
        "/branches",
        json={"repo_id": repo_id, "name": "feature-x", "commit_sha": "abcd1234"},
    ).json()
    listed = client.get(f"/branches?repo_id={repo_id}").json()
    assert any(b["name"] == branch["name"] for b in listed)


def test_branch_rejects_unknown_repo(client: TestClient) -> None:
    response = client.post(
        "/branches",
        json={"repo_id": "does-not-exist", "name": "x"},
    )
    assert response.status_code == 404
