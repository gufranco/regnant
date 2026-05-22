"""Pydantic models for the Open Service Broker API v2.16 surface."""

from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class CatalogPlanMaintenanceInfo(_Strict):
    version: str
    description: str | None = None


class CatalogPlan(_Strict):
    id: str
    name: str
    description: str
    free: bool = True
    bindable: bool = True
    plan_updateable: bool = True
    metadata: dict[str, Any] | None = None
    maintenance_info: CatalogPlanMaintenanceInfo | None = None


class CatalogService(_Strict):
    id: str
    name: str
    description: str
    tags: list[str] = Field(default_factory=list)
    requires: list[str] = Field(default_factory=list)
    bindable: bool = True
    plan_updateable: bool = True
    instances_retrievable: bool = True
    bindings_retrievable: bool = True
    plans: list[CatalogPlan]
    metadata: dict[str, Any] | None = None
    dashboard_client: dict[str, Any] | None = None


class Catalog(_Strict):
    services: list[CatalogService]


class ProvisionRequest(_Strict):
    service_id: str
    plan_id: str
    context: dict[str, Any] = Field(default_factory=dict)
    organization_guid: str | None = None
    space_guid: str | None = None
    parameters: dict[str, Any] = Field(default_factory=dict)
    maintenance_info: CatalogPlanMaintenanceInfo | None = None


class ProvisionResponse(_Strict):
    dashboard_url: str | None = None
    operation: str | None = None


class UpdateRequest(_Strict):
    service_id: str
    plan_id: str | None = None
    parameters: dict[str, Any] = Field(default_factory=dict)
    previous_values: dict[str, Any] | None = None
    context: dict[str, Any] = Field(default_factory=dict)
    maintenance_info: CatalogPlanMaintenanceInfo | None = None


class UpdateResponse(_Strict):
    dashboard_url: str | None = None
    operation: str | None = None


class FetchInstanceResponse(_Strict):
    service_id: str
    plan_id: str
    dashboard_url: str | None = None
    parameters: dict[str, Any] = Field(default_factory=dict)
    maintenance_info: CatalogPlanMaintenanceInfo | None = None


class BindResource(_Strict):
    app_guid: str | None = None
    route: str | None = None


class BindRequest(_Strict):
    service_id: str
    plan_id: str
    context: dict[str, Any] = Field(default_factory=dict)
    bind_resource: BindResource | None = None
    parameters: dict[str, Any] = Field(default_factory=dict)


class BindCredentials(_Strict):
    uri: str
    username: str
    password: str
    ca_certificate_pem: str | None = None


class BindResponse(_Strict):
    credentials: BindCredentials
    operation: str | None = None


class FetchBindingResponse(_Strict):
    credentials: BindCredentials | None = None
    parameters: dict[str, Any] = Field(default_factory=dict)


class LastOperationResponse(_Strict):
    state: Literal["in progress", "succeeded", "failed"]
    description: str | None = None
    instance_usable: bool | None = None
    update_repeatable: bool | None = None


class EmptyResponse(_Strict):
    operation: str | None = None
