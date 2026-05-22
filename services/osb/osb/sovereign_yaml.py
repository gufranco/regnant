"""Render Sovereign-shaped YAML for a service instance.

The Worker writes one of these per instance to S3 under
`envoy-resources/<instance_id>.yaml`. Sovereign's S3 context plugin
reads them and produces the rendered Envoy XDS responses.

This is intentionally not using the upstream `envoy_data_plane`
typed protobuf bindings yet; the YAML produced here matches Envoy's
data-plane-api field names exactly and is what Sovereign templates
expect to receive as context.
"""

from __future__ import annotations

from typing import Any

import yaml


def render_resources(instance_id: str, service_id: str, plan_id: str, parameters: dict[str, Any]) -> bytes:
    """Build the YAML body Sovereign reads as context for one instance."""

    upstream = parameters.get("upstream") or _default_upstream(service_id)
    listen_port = int(parameters.get("listen_port", 10000))
    cluster_name = f"{instance_id}-cluster"
    route_name = f"{instance_id}-route"
    listener_name = f"{instance_id}-listener"

    document: dict[str, Any] = {
        "metadata": {
            "instance_id": instance_id,
            "service_id": service_id,
            "plan_id": plan_id,
        },
        "clusters": [
            {
                "name": cluster_name,
                "connect_timeout": "2s",
                "type": "STRICT_DNS",
                "lb_policy": "ROUND_ROBIN",
                "transport_socket_matches": _transport_socket_matches(),
                "load_assignment": {
                    "cluster_name": cluster_name,
                    "endpoints": [
                        {
                            "lb_endpoints": [
                                {
                                    "endpoint": {
                                        "address": {
                                            "socket_address": {
                                                "address": upstream["host"],
                                                "port_value": upstream["port"],
                                            },
                                        },
                                    },
                                },
                            ],
                        },
                    ],
                },
                "health_checks": [
                    {
                        "timeout": "1s",
                        "interval": "5s",
                        "unhealthy_threshold": 2,
                        "healthy_threshold": 2,
                        "http_health_check": {"path": "/health"},
                    },
                ],
            },
        ],
        "routes": [
            {
                "name": route_name,
                "virtual_hosts": [
                    {
                        "name": f"vhost-{instance_id}",
                        "domains": parameters.get("domains", ["*"]),
                        "routes": [
                            {
                                "match": {"prefix": "/"},
                                "route": {"cluster": cluster_name, "timeout": "30s"},
                            },
                        ],
                    },
                ],
            },
        ],
        "listeners": [
            {
                "name": listener_name,
                "address": {
                    "socket_address": {
                        "address": "0.0.0.0",
                        "port_value": listen_port,
                    },
                },
                "filter_chains": [
                    {
                        "filters": [
                            {
                                "name": "envoy.filters.network.http_connection_manager",
                                "typed_config": _http_connection_manager(route_name),
                            },
                        ],
                    },
                ],
            },
        ],
        "secrets": [],
    }
    return yaml.safe_dump(document, sort_keys=False).encode("utf-8")


def _default_upstream(service_id: str) -> dict[str, Any]:
    if service_id.endswith("edge"):
        return {"host": "backend-bitbucket-clone", "port": 8080}
    if service_id.endswith("pro"):
        return {"host": "backend-confluence-clone", "port": 8080}
    return {"host": "backend-jira-clone", "port": 8080}


def _transport_socket_matches() -> list[dict[str, Any]]:
    return [
        {
            "name": "mtls",
            "match": {"tls_context": "required"},
            "transport_socket": {
                "name": "envoy.transport_sockets.tls",
                "typed_config": {
                    "@type": "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext",
                    "common_tls_context": {
                        "tls_certificate_sds_secret_configs": [
                            {"name": "envoy-mtls-cert", "sds_config": {"ads": {}}},
                        ],
                        "validation_context_sds_secret_config": {
                            "name": "regnant-ca", "sds_config": {"ads": {}},
                        },
                    },
                },
            },
        },
    ]


def _http_connection_manager(route_name: str) -> dict[str, Any]:
    return {
        "@type": "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager",
        "stat_prefix": "regnant_hcm",
        "codec_type": "AUTO",
        "use_remote_address": True,
        "common_http_protocol_options": {"idle_timeout": "300s"},
        "request_id_extension": {
            "typed_config": {
                "@type": "type.googleapis.com/envoy.extensions.request_id.uuid.v3.UuidRequestIdConfig",
            },
        },
        "tracing": {"random_sampling": {"value": 100.0}},
        "access_log": [
            {
                "name": "envoy.access_loggers.open_telemetry",
                "typed_config": {
                    "@type": "type.googleapis.com/envoy.extensions.access_loggers.open_telemetry.v3.OpenTelemetryAccessLogConfig",
                    "common_config": {
                        "log_name": "regnant_access",
                        "transport_api_version": "V3",
                        "grpc_service": {
                            "envoy_grpc": {"cluster_name": "otel-collector"},
                            "timeout": "1s",
                        },
                    },
                },
            },
        ],
        "http_filters": [
            {
                "name": "envoy.filters.http.ext_authz",
                "typed_config": {
                    "@type": "type.googleapis.com/envoy.extensions.filters.http.ext_authz.v3.ExtAuthz",
                    "grpc_service": {
                        "envoy_grpc": {"cluster_name": "auth-sidecar"},
                        "timeout": "500ms",
                    },
                    "transport_api_version": "V3",
                    "failure_mode_allow": False,
                },
            },
            {
                "name": "envoy.filters.http.ratelimit",
                "typed_config": {
                    "@type": "type.googleapis.com/envoy.extensions.filters.http.ratelimit.v3.RateLimit",
                    "domain": "regnant",
                    "rate_limit_service": {
                        "grpc_service": {
                            "envoy_grpc": {"cluster_name": "ratelimit"},
                            "timeout": "200ms",
                        },
                        "transport_api_version": "V3",
                    },
                },
            },
            {"name": "envoy.filters.http.router", "typed_config": {
                "@type": "type.googleapis.com/envoy.extensions.filters.http.router.v3.Router",
            }},
        ],
        "route_config": {
            "name": route_name,
            "virtual_hosts": [
                {
                    "name": f"resolved-{route_name}",
                    "domains": ["*"],
                    "routes": [
                        {"match": {"prefix": "/"}, "route": {"cluster": f"{route_name}-cluster"}},
                    ],
                },
            ],
        },
    }
