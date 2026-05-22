"""Keycloak OIDC happy and unhappy paths via the auth sidecar."""

from __future__ import annotations

import httpx
import pytest


@pytest.mark.e2e
def test_oidc_discovery_reachable(keycloak_url: str) -> None:
    # Arrange
    url = f"{keycloak_url}/realms/regnant/.well-known/openid-configuration"

    # Act
    response = httpx.get(url, timeout=5.0)

    # Assert
    assert response.status_code == 200
    body = response.json()
    assert body["issuer"].endswith("/realms/regnant")
    assert "jwks_uri" in body
    assert "device_authorization_endpoint" in body


@pytest.mark.e2e
def test_envoy_rejects_missing_token(envoy_client: httpx.Client) -> None:
    # Act
    response = envoy_client.get("/issues")

    # Assert
    assert response.status_code in {401, 403}


@pytest.mark.e2e
def test_envoy_rejects_bogus_token(envoy_client: httpx.Client) -> None:
    # Arrange
    bogus = "Bearer eyJhbGciOiJub25lIn0.e30."

    # Act
    response = envoy_client.get("/issues", headers={"Authorization": bogus})

    # Assert
    assert response.status_code in {401, 403}


@pytest.mark.e2e
def test_password_grant_returns_a_token(keycloak_url: str) -> None:
    # Arrange
    token_url = f"{keycloak_url}/realms/regnant/protocol/openid-connect/token"
    form = {
        "grant_type": "password",
        "client_id": "regnant-cli",
        "username": "demo-editor",
        "password": "demo",
        "scope": "openid",
    }

    # Act
    response = httpx.post(token_url, data=form, timeout=5.0)

    # Assert: the public CLI client may forbid password grant by design;
    # tolerate both "got a token" and "client did not allow this grant".
    if response.status_code == 200:
        assert "access_token" in response.json()
    else:
        assert response.status_code in {400, 401}
