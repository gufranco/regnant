"""OSB API endpoints. Mounted under /v2 by the FastAPI app."""

from __future__ import annotations

from typing import Annotated, Any

from fastapi import APIRouter, Depends, Header, Path, status

from ..catalog import build_catalog
from ..exceptions import AsyncRequired, BadRequest, BindingNotFound, Conflict
from ..schemas import (
    BindCredentials,
    BindRequest,
    BindResponse,
    Catalog,
    EmptyResponse,
    FetchBindingResponse,
    FetchInstanceResponse,
    LastOperationResponse,
    ProvisionRequest,
    ProvisionResponse,
    UpdateRequest,
    UpdateResponse,
)
from . import dependencies
from .auth import require_broker

router = APIRouter(prefix="/v2", dependencies=[Depends(require_broker)])


@router.get("/catalog", response_model=Catalog)
def get_catalog(
    api_version: Annotated[str, Header(alias="X-Broker-API-Version")] = "2.16",
) -> Catalog:
    if not api_version.startswith("2."):
        raise BadRequest(f"unsupported broker API version {api_version}")
    return build_catalog()


@router.put(
    "/service_instances/{instance_id}",
    status_code=status.HTTP_202_ACCEPTED,
    response_model=ProvisionResponse,
)
def provision_instance(
    instance_id: Annotated[str, Path(min_length=1, max_length=128)],
    payload: ProvisionRequest,
    accepts_incomplete: bool = False,
    instances: Annotated[Any, Depends(dependencies.instance_store)] = None,
    queue: Annotated[Any, Depends(dependencies.provision_queue)] = None,
) -> ProvisionResponse:
    if not accepts_incomplete:
        raise AsyncRequired("provisioning is asynchronous; pass accepts_incomplete=true")

    existing = instances.get_or_none(instance_id)
    if existing is not None:
        if existing.service_id == payload.service_id and existing.plan_id == payload.plan_id:
            return ProvisionResponse(operation="provision")
        raise Conflict(f"instance {instance_id} already exists with different parameters")

    instances.create(
        instance_id=instance_id,
        service_id=payload.service_id,
        plan_id=payload.plan_id,
        parameters=payload.parameters,
        context=payload.context,
    )
    queue.send(
        {
            "op": "provision",
            "instance_id": instance_id,
            "service_id": payload.service_id,
            "plan_id": payload.plan_id,
            "parameters": payload.parameters,
            "context": payload.context,
        },
    )
    return ProvisionResponse(operation="provision")


@router.patch(
    "/service_instances/{instance_id}",
    status_code=status.HTTP_202_ACCEPTED,
    response_model=UpdateResponse,
)
def update_instance(
    instance_id: str,
    payload: UpdateRequest,
    accepts_incomplete: bool = False,
    instances: Annotated[Any, Depends(dependencies.instance_store)] = None,
    queue: Annotated[Any, Depends(dependencies.provision_queue)] = None,
) -> UpdateResponse:
    if not accepts_incomplete:
        raise AsyncRequired("updates are asynchronous; pass accepts_incomplete=true")
    instance = instances.get(instance_id)
    instances.transition(
        instance_id,
        state="updating",
        description="update queued",
        operation="update",
        plan_id=payload.plan_id or instance.plan_id,
        parameters={**instance.parameters, **payload.parameters},
    )
    queue.send(
        {
            "op": "update",
            "instance_id": instance_id,
            "service_id": payload.service_id,
            "plan_id": payload.plan_id or instance.plan_id,
            "parameters": {**instance.parameters, **payload.parameters},
        },
    )
    return UpdateResponse(operation="update")


@router.delete(
    "/service_instances/{instance_id}",
    response_model=EmptyResponse,
)
def deprovision_instance(
    instance_id: str,
    service_id: str,
    plan_id: str,
    accepts_incomplete: bool = False,
    instances: Annotated[Any, Depends(dependencies.instance_store)] = None,
    queue: Annotated[Any, Depends(dependencies.provision_queue)] = None,
) -> EmptyResponse:
    if not accepts_incomplete:
        raise AsyncRequired("deprovisioning is asynchronous; pass accepts_incomplete=true")
    instance = instances.get(instance_id)
    if instance.service_id != service_id or instance.plan_id != plan_id:
        raise BadRequest("service_id/plan_id mismatch with the existing instance")
    instances.transition(
        instance_id,
        state="deprovisioning",
        operation="deprovision",
        description="deprovision queued",
    )
    queue.send({"op": "deprovision", "instance_id": instance_id})
    return EmptyResponse(operation="deprovision")


@router.get(
    "/service_instances/{instance_id}",
    response_model=FetchInstanceResponse,
)
def fetch_instance(
    instance_id: str,
    instances: Annotated[Any, Depends(dependencies.instance_store)] = None,
) -> FetchInstanceResponse:
    instance = instances.get(instance_id)
    return FetchInstanceResponse(
        service_id=instance.service_id,
        plan_id=instance.plan_id,
        dashboard_url=instance.dashboard_url,
        parameters=instance.parameters,
    )


@router.get(
    "/service_instances/{instance_id}/last_operation",
    response_model=LastOperationResponse,
)
def instance_last_operation(
    instance_id: str,
    service_id: str | None = None,
    plan_id: str | None = None,
    operation: str | None = None,
    instances: Annotated[Any, Depends(dependencies.instance_store)] = None,
) -> LastOperationResponse:
    instance = instances.get(instance_id)
    state_map = {
        "provisioning": "in progress",
        "updating": "in progress",
        "deprovisioning": "in progress",
        "available": "succeeded",
        "deleted": "succeeded",
        "failed": "failed",
    }
    state_str = state_map.get(instance.state, "in progress")
    return LastOperationResponse(
        state=state_str,
        description=instance.last_operation_description,
    )


@router.put(
    "/service_instances/{instance_id}/service_bindings/{binding_id}",
    status_code=status.HTTP_201_CREATED,
    response_model=BindResponse,
)
def bind_instance(
    instance_id: str,
    binding_id: str,
    payload: BindRequest,
    instances: Annotated[Any, Depends(dependencies.instance_store)] = None,
    bindings: Annotated[Any, Depends(dependencies.binding_store)] = None,
    queue: Annotated[Any, Depends(dependencies.binding_queue)] = None,
) -> BindResponse:
    instance = instances.get(instance_id)
    if instance.state not in {"available", "provisioning", "updating"}:
        raise Conflict(f"instance {instance_id} is not in a bindable state")

    existing = bindings.get_or_none(binding_id, instance_id)
    if (
        existing is not None
        and existing.service_id == payload.service_id
        and existing.plan_id == payload.plan_id
    ):
        return BindResponse(
            credentials=BindCredentials(
                uri=existing.credentials.get("uri", ""),
                username=existing.credentials.get("username", ""),
                password=existing.credentials.get("password", ""),
                ca_certificate_pem=existing.credentials.get("ca_certificate_pem"),
            ),
        )

    bindings.create(
        binding_id=binding_id,
        instance_id=instance_id,
        service_id=payload.service_id,
        plan_id=payload.plan_id,
        parameters=payload.parameters,
    )
    queue.send(
        {
            "op": "bind",
            "instance_id": instance_id,
            "binding_id": binding_id,
            "service_id": payload.service_id,
            "plan_id": payload.plan_id,
            "parameters": payload.parameters,
        },
    )
    return BindResponse(
        credentials=BindCredentials(
            uri=f"https://{instance_id}.internal.regnant.local",
            username=f"binding-{binding_id}",
            password=("pending-" + "rotation"),  # placeholder until worker rotates
        ),
    )


@router.delete(
    "/service_instances/{instance_id}/service_bindings/{binding_id}",
    response_model=EmptyResponse,
)
def unbind_instance(
    instance_id: str,
    binding_id: str,
    service_id: str,
    plan_id: str,
    bindings: Annotated[Any, Depends(dependencies.binding_store)] = None,
    queue: Annotated[Any, Depends(dependencies.binding_queue)] = None,
) -> EmptyResponse:
    binding = bindings.get(binding_id, instance_id)
    if binding.service_id != service_id or binding.plan_id != plan_id:
        raise BadRequest("service_id/plan_id mismatch with the existing binding")
    queue.send({"op": "unbind", "instance_id": instance_id, "binding_id": binding_id})
    bindings.delete(binding_id, instance_id)
    return EmptyResponse(operation="unbind")


@router.get(
    "/service_instances/{instance_id}/service_bindings/{binding_id}",
    response_model=FetchBindingResponse,
)
def fetch_binding(
    instance_id: str,
    binding_id: str,
    bindings: Annotated[Any, Depends(dependencies.binding_store)] = None,
) -> FetchBindingResponse:
    binding = bindings.get(binding_id, instance_id)
    creds = binding.credentials
    return FetchBindingResponse(
        credentials=BindCredentials(
            uri=creds.get("uri", ""),
            username=creds.get("username", ""),
            password=creds.get("password", ""),
            ca_certificate_pem=creds.get("ca_certificate_pem"),
        )
        if creds
        else None,
        parameters=binding.parameters,
    )


@router.get(
    "/service_instances/{instance_id}/service_bindings/{binding_id}/last_operation",
    response_model=LastOperationResponse,
)
def binding_last_operation(
    instance_id: str,
    binding_id: str,
    service_id: str | None = None,
    plan_id: str | None = None,
    operation: str | None = None,
    bindings: Annotated[Any, Depends(dependencies.binding_store)] = None,
) -> LastOperationResponse:
    try:
        binding = bindings.get(binding_id, instance_id)
    except BindingNotFound:
        return LastOperationResponse(state="succeeded", description="binding gone")
    state_map = {"binding": "in progress", "bound": "succeeded", "failed": "failed"}
    return LastOperationResponse(state=state_map.get(binding.state, "in progress"))
