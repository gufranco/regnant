"""Worker loop: pull SQS messages, dispatch by op, update DDB + S3."""

from __future__ import annotations

import json
import signal
import sys
import time
from typing import Any

import structlog

from ..config import get_settings
from ..exceptions import InstanceNotFound, OsbError
from ..observability import setup as setup_observability
from ..sovereign_yaml import render_resources
from ..storage import ArtifactStore, BindingStore, InstanceStore, TaskQueue

logger = structlog.get_logger(__name__)


class WorkerStopped(Exception):
    """Raised when SIGTERM/SIGINT requests a graceful stop."""


class Worker:
    def __init__(self) -> None:
        settings = get_settings()
        self._instances = InstanceStore()
        self._bindings = BindingStore()
        self._artifacts = ArtifactStore()
        self._provision_queue = TaskQueue(settings.provision_queue_url)
        self._binding_queue = TaskQueue(settings.binding_queue_url)
        self._settings = settings
        self._stopping = False

    def request_stop(self, *_: Any) -> None:
        self._stopping = True

    def run(self) -> None:
        signal.signal(signal.SIGTERM, self.request_stop)
        signal.signal(signal.SIGINT, self.request_stop)

        logger.info("worker starting", queues=[self._provision_queue, self._binding_queue])
        while not self._stopping:
            handled = self._tick(self._provision_queue) + self._tick(self._binding_queue)
            if handled == 0:
                time.sleep(0.5)
        logger.info("worker stopped")

    def _tick(self, queue: TaskQueue) -> int:
        messages = queue.receive(
            max_messages=self._settings.worker_max_messages,
            wait_seconds=self._settings.worker_poll_seconds,
            visibility_seconds=self._settings.worker_visibility_seconds,
        )
        for message in messages:
            self._handle(queue, message)
        return len(messages)

    def _handle(self, queue: TaskQueue, message: dict[str, Any]) -> None:
        body = message.get("Body", "{}")
        try:
            payload = json.loads(body)
        except json.JSONDecodeError:
            logger.error("malformed message body", body=body)
            queue.delete(message["ReceiptHandle"])
            return

        op = payload.get("op")
        log = logger.bind(op=op, message_id=message.get("MessageId"))
        try:
            if op == "provision":
                self._provision(payload)
            elif op == "update":
                self._update(payload)
            elif op == "deprovision":
                self._deprovision(payload)
            elif op == "bind":
                self._bind(payload)
            elif op == "unbind":
                self._unbind(payload)
            else:
                log.error("unknown op")
        except OsbError as exc:
            log.error("op failed (domain)", err=str(exc), error_code=exc.error_code)
        except Exception as exc:  # noqa: BLE001
            log.error("op failed (unexpected)", err=str(exc))
            return  # leave for DLQ via redrive
        else:
            queue.delete(message["ReceiptHandle"])

    def _provision(self, payload: dict[str, Any]) -> None:
        instance_id = payload["instance_id"]
        yaml_bytes = render_resources(
            instance_id=instance_id,
            service_id=payload["service_id"],
            plan_id=payload["plan_id"],
            parameters=payload.get("parameters", {}),
        )
        key = self._artifacts.write(instance_id, yaml_bytes)
        self._instances.transition(
            instance_id,
            state="available",
            description="provisioned",
            operation="provision",
            artifact_key=key,
            dashboard_url=f"https://api.regnant.local/dashboard/{instance_id}",
        )

    def _update(self, payload: dict[str, Any]) -> None:
        instance_id = payload["instance_id"]
        try:
            instance = self._instances.get(instance_id)
        except InstanceNotFound:
            logger.warning("update for missing instance", instance_id=instance_id)
            return

        yaml_bytes = render_resources(
            instance_id=instance_id,
            service_id=payload.get("service_id", instance.service_id),
            plan_id=payload.get("plan_id", instance.plan_id),
            parameters=payload.get("parameters", instance.parameters),
        )
        key = self._artifacts.write(instance_id, yaml_bytes)
        self._instances.transition(
            instance_id,
            state="available",
            description="updated",
            operation="update",
            artifact_key=key,
            plan_id=payload.get("plan_id"),
            parameters=payload.get("parameters"),
        )

    def _deprovision(self, payload: dict[str, Any]) -> None:
        instance_id = payload["instance_id"]
        self._artifacts.delete(instance_id)
        self._instances.delete(instance_id)

    def _bind(self, payload: dict[str, Any]) -> None:
        credentials = {
            "uri": f"https://{payload['instance_id']}.internal.regnant.local",
            "username": f"binding-{payload['binding_id']}",
            "password": _generate_credential(),
        }
        self._bindings.complete(
            binding_id=payload["binding_id"],
            instance_id=payload["instance_id"],
            credentials=credentials,
        )

    def _unbind(self, payload: dict[str, Any]) -> None:
        # The API already removed the row before queuing; this is a no-op
        # except for any platform-side cleanup we want to do later.
        logger.info("unbind handled", binding_id=payload["binding_id"])


def _generate_credential() -> str:
    import secrets

    return secrets.token_urlsafe(24)


def run() -> int:
    setup_observability()
    worker = Worker()
    try:
        worker.run()
    except KeyboardInterrupt:
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(run())
