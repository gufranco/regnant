"""Static catalog the broker advertises."""

from __future__ import annotations

from .schemas import Catalog, CatalogPlan, CatalogPlanMaintenanceInfo, CatalogService


def build_catalog() -> Catalog:
    """Three offerings (basic, pro, edge) with two plans each."""

    maintenance = CatalogPlanMaintenanceInfo(version="1.0.0", description="initial release")

    def _plans(prefix: str) -> list[CatalogPlan]:
        return [
            CatalogPlan(
                id=f"{prefix}-single",
                name="single-az",
                description="One-AZ deployment, lowest cost.",
                free=False,
                bindable=True,
                plan_updateable=True,
                maintenance_info=maintenance,
            ),
            CatalogPlan(
                id=f"{prefix}-multi",
                name="multi-az",
                description="Multi-AZ deployment with cross-zone load balancing.",
                free=False,
                bindable=True,
                plan_updateable=True,
                maintenance_info=maintenance,
            ),
        ]

    services = [
        CatalogService(
            id="regnant-lb-basic",
            name="regnant-lb-basic",
            description="Layer-4 load balancer backed by the Envoy fleet.",
            tags=["load-balancer", "envoy", "regnant"],
            bindable=True,
            plan_updateable=True,
            instances_retrievable=True,
            bindings_retrievable=True,
            plans=_plans("regnant-lb-basic"),
            metadata={"displayName": "Regnant LB Basic", "longDescription": "Baseline L4 LB"},
        ),
        CatalogService(
            id="regnant-lb-pro",
            name="regnant-lb-pro",
            description="L7 load balancer with auth, ratelimit, and OTel access logs.",
            tags=["load-balancer", "envoy", "regnant", "pro"],
            bindable=True,
            plan_updateable=True,
            instances_retrievable=True,
            bindings_retrievable=True,
            plans=_plans("regnant-lb-pro"),
            metadata={"displayName": "Regnant LB Pro", "longDescription": "Edge concerns built in"},
        ),
        CatalogService(
            id="regnant-lb-edge",
            name="regnant-lb-edge",
            description="LB Pro plus CloudFront and WAF integration.",
            tags=["load-balancer", "envoy", "regnant", "edge"],
            bindable=True,
            plan_updateable=True,
            instances_retrievable=True,
            bindings_retrievable=True,
            plans=_plans("regnant-lb-edge"),
            metadata={"displayName": "Regnant LB Edge", "longDescription": "End-to-end edge"},
        ),
    ]
    return Catalog(services=services)
