"""Full bind/unbind cycle per the OSB spec."""

from __future__ import annotations

import httpx
import pytest


@pytest.mark.e2e
def test_bind_and_unbind_cycle(
    osb_client: httpx.Client,
    instance_id: str,
    binding_id: str,
) -> None:
    # Arrange: provision the parent instance first.
    osb_client.put(
        f"/v2/service_instances/{instance_id}",
        params={"accepts_incomplete": "true"},
        json={
            "service_id": "regnant-lb-pro",
            "plan_id": "regnant-lb-pro-single",
        },
    ).raise_for_status()

    # Act: bind.
    bind_response = osb_client.put(
        f"/v2/service_instances/{instance_id}/service_bindings/{binding_id}",
        json={
            "service_id": "regnant-lb-pro",
            "plan_id": "regnant-lb-pro-single",
            "bind_resource": {"app_guid": "e2e-app"},
            "parameters": {"app": "e2e"},
        },
    )

    # Assert
    assert bind_response.status_code == 201
    credentials = bind_response.json()["credentials"]
    assert credentials["uri"].startswith("https://")
    assert credentials["username"].startswith("binding-")

    # Act: fetch the binding.
    fetch = osb_client.get(
        f"/v2/service_instances/{instance_id}/service_bindings/{binding_id}"
    )
    assert fetch.status_code == 200

    # Act: unbind.
    unbind = osb_client.delete(
        f"/v2/service_instances/{instance_id}/service_bindings/{binding_id}",
        params={
            "service_id": "regnant-lb-pro",
            "plan_id": "regnant-lb-pro-single",
        },
    )
    assert unbind.status_code == 200

    # Assert: gone.
    after = osb_client.get(
        f"/v2/service_instances/{instance_id}/service_bindings/{binding_id}"
    )
    assert after.status_code == 404
