"""Thin wrappers around the AWS resources the broker depends on."""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

import boto3
import structlog
from botocore.config import Config

from .config import get_settings
from .exceptions import ConcurrencyError, InstanceNotFound, BindingNotFound

logger = structlog.get_logger(__name__)


def _boto_config() -> Config:
    return Config(
        retries={"max_attempts": 10, "mode": "standard"},
        connect_timeout=5,
        read_timeout=10,
    )


def _client(service: str) -> Any:
    settings = get_settings()
    return boto3.client(
        service,
        endpoint_url=settings.aws_endpoint_url,
        region_name=settings.aws_region,
        aws_access_key_id=settings.aws_access_key_id,
        aws_secret_access_key=settings.aws_secret_access_key,
        config=_boto_config(),
    )


def _resource(service: str) -> Any:
    settings = get_settings()
    return boto3.resource(
        service,
        endpoint_url=settings.aws_endpoint_url,
        region_name=settings.aws_region,
        aws_access_key_id=settings.aws_access_key_id,
        aws_secret_access_key=settings.aws_secret_access_key,
        config=_boto_config(),
    )


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass(frozen=True, slots=True)
class Instance:
    instance_id: str
    service_id: str
    plan_id: str
    state: str
    parameters: dict[str, Any]
    context: dict[str, Any]
    artifact_key: str | None
    created_at: str
    updated_at: str
    last_operation: str | None
    last_operation_description: str | None
    dashboard_url: str | None


@dataclass(frozen=True, slots=True)
class Binding:
    binding_id: str
    instance_id: str
    service_id: str
    plan_id: str
    state: str
    credentials: dict[str, Any]
    parameters: dict[str, Any]
    created_at: str
    updated_at: str


class InstanceStore:
    """DynamoDB-backed store for service instances."""

    def __init__(self) -> None:
        self._table = _resource("dynamodb").Table(get_settings().instances_table)

    def get(self, instance_id: str) -> Instance:
        response = self._table.get_item(Key={"instance_id": instance_id})
        item = response.get("Item")
        if not item:
            raise InstanceNotFound(f"instance {instance_id} not found")
        return _instance_from_item(item)

    def get_or_none(self, instance_id: str) -> Instance | None:
        try:
            return self.get(instance_id)
        except InstanceNotFound:
            return None

    def create(
        self,
        *,
        instance_id: str,
        service_id: str,
        plan_id: str,
        parameters: dict[str, Any],
        context: dict[str, Any],
    ) -> Instance:
        now = _now()
        item = {
            "instance_id": instance_id,
            "service_id": service_id,
            "plan_id": plan_id,
            "state": "provisioning",
            "parameters": parameters,
            "context": context,
            "artifact_key": None,
            "created_at": now,
            "updated_at": now,
            "last_operation": "provision",
            "last_operation_description": "queued",
            "dashboard_url": None,
        }
        try:
            self._table.put_item(
                Item=item,
                ConditionExpression="attribute_not_exists(instance_id)",
            )
        except self._table.meta.client.exceptions.ConditionalCheckFailedException as exc:
            raise ConcurrencyError(f"instance {instance_id} already exists") from exc
        return _instance_from_item(item)

    def transition(
        self,
        instance_id: str,
        *,
        state: str,
        description: str | None = None,
        operation: str | None = None,
        artifact_key: str | None = None,
        plan_id: str | None = None,
        parameters: dict[str, Any] | None = None,
        dashboard_url: str | None = None,
    ) -> None:
        updates: list[str] = ["#state = :state", "updated_at = :ts"]
        names = {"#state": "state"}
        values: dict[str, Any] = {":state": state, ":ts": _now()}
        if description is not None:
            updates.append("last_operation_description = :desc")
            values[":desc"] = description
        if operation is not None:
            updates.append("last_operation = :op")
            values[":op"] = operation
        if artifact_key is not None:
            updates.append("artifact_key = :ak")
            values[":ak"] = artifact_key
        if plan_id is not None:
            updates.append("plan_id = :plan")
            values[":plan"] = plan_id
        if parameters is not None:
            updates.append("#params = :params")
            names["#params"] = "parameters"
            values[":params"] = parameters
        if dashboard_url is not None:
            updates.append("dashboard_url = :url")
            values[":url"] = dashboard_url
        self._table.update_item(
            Key={"instance_id": instance_id},
            UpdateExpression="SET " + ", ".join(updates),
            ExpressionAttributeNames=names,
            ExpressionAttributeValues=values,
        )

    def delete(self, instance_id: str) -> None:
        self._table.delete_item(Key={"instance_id": instance_id})


class BindingStore:
    """DynamoDB-backed store for service bindings."""

    def __init__(self) -> None:
        self._table = _resource("dynamodb").Table(get_settings().bindings_table)

    def get(self, binding_id: str, instance_id: str) -> Binding:
        response = self._table.get_item(
            Key={"binding_id": binding_id, "instance_id": instance_id},
        )
        item = response.get("Item")
        if not item:
            raise BindingNotFound(f"binding {binding_id} not found")
        return _binding_from_item(item)

    def get_or_none(self, binding_id: str, instance_id: str) -> Binding | None:
        try:
            return self.get(binding_id, instance_id)
        except BindingNotFound:
            return None

    def create(
        self,
        *,
        binding_id: str,
        instance_id: str,
        service_id: str,
        plan_id: str,
        parameters: dict[str, Any],
    ) -> Binding:
        now = _now()
        item = {
            "binding_id": binding_id,
            "instance_id": instance_id,
            "service_id": service_id,
            "plan_id": plan_id,
            "state": "binding",
            "credentials": {},
            "parameters": parameters,
            "created_at": now,
            "updated_at": now,
        }
        try:
            self._table.put_item(
                Item=item,
                ConditionExpression="attribute_not_exists(binding_id)",
            )
        except self._table.meta.client.exceptions.ConditionalCheckFailedException as exc:
            raise ConcurrencyError(f"binding {binding_id} already exists") from exc
        return _binding_from_item(item)

    def complete(
        self,
        *,
        binding_id: str,
        instance_id: str,
        credentials: dict[str, Any],
    ) -> None:
        self._table.update_item(
            Key={"binding_id": binding_id, "instance_id": instance_id},
            UpdateExpression="SET #state = :state, credentials = :creds, updated_at = :ts",
            ExpressionAttributeNames={"#state": "state"},
            ExpressionAttributeValues={
                ":state": "bound",
                ":creds": credentials,
                ":ts": _now(),
            },
        )

    def delete(self, binding_id: str, instance_id: str) -> None:
        self._table.delete_item(
            Key={"binding_id": binding_id, "instance_id": instance_id},
        )


class ArtifactStore:
    """S3-backed store for Sovereign-shaped YAML artifacts."""

    def __init__(self) -> None:
        self._client = _client("s3")
        self._bucket = get_settings().artifact_bucket
        self._prefix = get_settings().artifact_prefix

    def write(self, instance_id: str, yaml_bytes: bytes) -> str:
        key = f"{self._prefix}{instance_id}.yaml"
        self._client.put_object(
            Bucket=self._bucket,
            Key=key,
            Body=yaml_bytes,
            ContentType="application/yaml",
            ServerSideEncryption="aws:kms",
        )
        return key

    def delete(self, instance_id: str) -> None:
        key = f"{self._prefix}{instance_id}.yaml"
        self._client.delete_object(Bucket=self._bucket, Key=key)


class TaskQueue:
    """SQS-backed queue for asynchronous provisioning work."""

    def __init__(self, queue_url: str) -> None:
        self._client = _client("sqs")
        self._queue_url = queue_url

    def send(self, payload: dict[str, Any]) -> None:
        self._client.send_message(
            QueueUrl=self._queue_url,
            MessageBody=json.dumps(payload, separators=(",", ":")),
        )

    def receive(self, *, max_messages: int, wait_seconds: int, visibility_seconds: int) -> list[dict[str, Any]]:
        response = self._client.receive_message(
            QueueUrl=self._queue_url,
            MaxNumberOfMessages=max_messages,
            WaitTimeSeconds=wait_seconds,
            VisibilityTimeout=visibility_seconds,
            MessageAttributeNames=["All"],
        )
        return list(response.get("Messages", []))

    def delete(self, receipt_handle: str) -> None:
        self._client.delete_message(QueueUrl=self._queue_url, ReceiptHandle=receipt_handle)


def _instance_from_item(item: dict[str, Any]) -> Instance:
    return Instance(
        instance_id=item["instance_id"],
        service_id=item["service_id"],
        plan_id=item["plan_id"],
        state=item["state"],
        parameters=dict(item.get("parameters", {})),
        context=dict(item.get("context", {})),
        artifact_key=item.get("artifact_key"),
        created_at=item["created_at"],
        updated_at=item["updated_at"],
        last_operation=item.get("last_operation"),
        last_operation_description=item.get("last_operation_description"),
        dashboard_url=item.get("dashboard_url"),
    )


def _binding_from_item(item: dict[str, Any]) -> Binding:
    return Binding(
        binding_id=item["binding_id"],
        instance_id=item["instance_id"],
        service_id=item["service_id"],
        plan_id=item["plan_id"],
        state=item["state"],
        credentials=dict(item.get("credentials", {})),
        parameters=dict(item.get("parameters", {})),
        created_at=item["created_at"],
        updated_at=item["updated_at"],
    )
