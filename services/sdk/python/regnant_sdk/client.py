"""Synchronous and asynchronous OSB clients."""

from __future__ import annotations

import httpx

from .models import (
    BindRequest,
    BindResponse,
    Catalog,
    LastOperation,
    ProvisionRequest,
    ProvisionResponse,
)


class RegnantClient:
    """Thin OSB v2.16 client with sync and async surfaces."""

    def __init__(
        self,
        base_url: str,
        username: str,
        password: str,
        *,
        timeout: float = 10.0,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._auth = (username, password)
        self._headers = {"X-Broker-API-Version": "2.16"}
        self._timeout = timeout

    def _sync(self) -> httpx.Client:
        return httpx.Client(
            base_url=self._base_url,
            auth=self._auth,
            headers=self._headers,
            timeout=self._timeout,
        )

    def _async(self) -> httpx.AsyncClient:
        return httpx.AsyncClient(
            base_url=self._base_url,
            auth=self._auth,
            headers=self._headers,
            timeout=self._timeout,
        )

    def get_catalog(self) -> Catalog:
        with self._sync() as client:
            response = client.get("/v2/catalog")
            response.raise_for_status()
            return Catalog.model_validate(response.json())

    def provision(self, instance_id: str, request: ProvisionRequest) -> ProvisionResponse:
        with self._sync() as client:
            response = client.put(
                f"/v2/service_instances/{instance_id}",
                params={"accepts_incomplete": "true"},
                json=request.model_dump(mode="json"),
            )
            response.raise_for_status()
            return ProvisionResponse.model_validate(response.json())

    def deprovision(self, instance_id: str, service_id: str, plan_id: str) -> None:
        with self._sync() as client:
            response = client.delete(
                f"/v2/service_instances/{instance_id}",
                params={
                    "accepts_incomplete": "true",
                    "service_id": service_id,
                    "plan_id": plan_id,
                },
            )
            response.raise_for_status()

    def last_operation(self, instance_id: str) -> LastOperation:
        with self._sync() as client:
            response = client.get(f"/v2/service_instances/{instance_id}/last_operation")
            response.raise_for_status()
            return LastOperation.model_validate(response.json())

    def bind(self, instance_id: str, binding_id: str, request: BindRequest) -> BindResponse:
        with self._sync() as client:
            response = client.put(
                f"/v2/service_instances/{instance_id}/service_bindings/{binding_id}",
                json=request.model_dump(mode="json"),
            )
            response.raise_for_status()
            return BindResponse.model_validate(response.json())

    def unbind(
        self,
        instance_id: str,
        binding_id: str,
        service_id: str,
        plan_id: str,
    ) -> None:
        with self._sync() as client:
            response = client.delete(
                f"/v2/service_instances/{instance_id}/service_bindings/{binding_id}",
                params={"service_id": service_id, "plan_id": plan_id},
            )
            response.raise_for_status()

    async def aget_catalog(self) -> Catalog:
        async with self._async() as client:
            response = await client.get("/v2/catalog")
            response.raise_for_status()
            return Catalog.model_validate(response.json())

    async def aprovision(self, instance_id: str, request: ProvisionRequest) -> ProvisionResponse:
        async with self._async() as client:
            response = await client.put(
                f"/v2/service_instances/{instance_id}",
                params={"accepts_incomplete": "true"},
                json=request.model_dump(mode="json"),
            )
            response.raise_for_status()
            return ProvisionResponse.model_validate(response.json())

    async def alast_operation(self, instance_id: str) -> LastOperation:
        async with self._async() as client:
            response = await client.get(f"/v2/service_instances/{instance_id}/last_operation")
            response.raise_for_status()
            return LastOperation.model_validate(response.json())
