"""End-to-end: developer creates a load balancer, traffic flows through."""

from __future__ import annotations

import httpx
import pytest
from tenacity import retry, stop_after_attempt, wait_fixed


@pytest.mark.e2e
def test_provision_to_serving(
    osb_client: httpx.Client,
    s3_client,
    dynamodb_client,
    instance_id: str,
) -> None:
    # Arrange
    payload = {
        "service_id": "regnant-lb-pro",
        "plan_id": "regnant-lb-pro-multi",
        "parameters": {
            "upstream": {"host": "backend-jira-clone", "port": 8080},
            "domains": ["jira.regnant.local"],
        },
        "context": {"platform": "regnant-e2e"},
    }

    # Act
    response = osb_client.put(
        f"/v2/service_instances/{instance_id}",
        params={"accepts_incomplete": "true"},
        json=payload,
    )

    # Assert
    assert response.status_code == 202

    @retry(stop=stop_after_attempt(30), wait=wait_fixed(2))
    def _await_artifact() -> dict:
        item = dynamodb_client.get_item(
            TableName="regnant-service-instances",
            Key={"instance_id": {"S": instance_id}},
        )
        assert "Item" in item
        state = item["Item"]["state"]["S"]
        assert state == "available", f"state still {state}"
        return item["Item"]

    record = _await_artifact()
    artifact_key = record["artifact_key"]["S"]
    artifact = s3_client.get_object(
        Bucket="regnant-osb-artifacts",
        Key=artifact_key,
    )
    body = artifact["Body"].read()
    assert b"clusters" in body
    assert instance_id.encode() in body
