"""Typed request/response models matching the OpenAPI spec."""

from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


class CatalogPlan(BaseModel):
    id: str
    name: str
    description: str
    free: bool = True
    bindable: bool = True


class CatalogService(BaseModel):
    id: str
    name: str
    description: str
    tags: list[str] = Field(default_factory=list)
    bindable: bool = True
    plan_updateable: bool = True
    plans: list[CatalogPlan]


class Catalog(BaseModel):
    services: list[CatalogService]


class ProvisionRequest(BaseModel):
    service_id: str
    plan_id: str
    context: dict[str, Any] = Field(default_factory=dict)
    parameters: dict[str, Any] = Field(default_factory=dict)


class ProvisionResponse(BaseModel):
    dashboard_url: str | None = None
    operation: str | None = None


class BindRequest(BaseModel):
    service_id: str
    plan_id: str
    parameters: dict[str, Any] = Field(default_factory=dict)
    bind_resource: dict[str, Any] | None = None


class BindCredentials(BaseModel):
    uri: str
    username: str
    password: str
    ca_certificate_pem: str | None = None


class BindResponse(BaseModel):
    credentials: BindCredentials
    operation: str | None = None


class LastOperation(BaseModel):
    state: Literal["in progress", "succeeded", "failed"]
    description: str | None = None
