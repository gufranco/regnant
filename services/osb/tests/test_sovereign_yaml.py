"""Sovereign YAML rendering produces the expected shape."""

from __future__ import annotations

import yaml

from osb.sovereign_yaml import render_resources


def test_render_resources_emits_clusters_routes_listeners() -> None:
    # Arrange
    instance_id = "test-instance"
    parameters = {
        "upstream": {"host": "backend-jira-clone", "port": 8080},
        "listen_port": 10000,
        "domains": ["jira.regnant.local"],
    }

    # Act
    raw = render_resources(
        instance_id=instance_id,
        service_id="regnant-lb-pro",
        plan_id="regnant-lb-pro-single",
        parameters=parameters,
    )
    doc = yaml.safe_load(raw)

    # Assert
    assert doc["metadata"]["instance_id"] == instance_id
    assert {c["name"] for c in doc["clusters"]} == {f"{instance_id}-cluster"}
    assert doc["routes"][0]["virtual_hosts"][0]["domains"] == ["jira.regnant.local"]
    assert doc["listeners"][0]["address"]["socket_address"]["port_value"] == 10000
    filters = doc["listeners"][0]["filter_chains"][0]["filters"]
    assert filters[0]["name"] == "envoy.filters.network.http_connection_manager"


def test_render_resources_defaults_per_service_id() -> None:
    # Arrange
    instance_id = "edge-instance"

    # Act
    raw = render_resources(
        instance_id=instance_id,
        service_id="regnant-lb-edge",
        plan_id="regnant-lb-edge-single",
        parameters={},
    )
    doc = yaml.safe_load(raw)

    # Assert
    upstream = doc["clusters"][0]["load_assignment"]["endpoints"][0]["lb_endpoints"][0]["endpoint"][
        "address"
    ]["socket_address"]
    assert upstream["address"] == "backend-bitbucket-clone"
    assert upstream["port_value"] == 8080
