"""FastAPI dependency wiring for the storage layer."""

from __future__ import annotations

from functools import lru_cache

from ..config import get_settings
from ..storage import ArtifactStore, BindingStore, InstanceStore, TaskQueue


@lru_cache(maxsize=1)
def instance_store() -> InstanceStore:
    return InstanceStore()


@lru_cache(maxsize=1)
def binding_store() -> BindingStore:
    return BindingStore()


@lru_cache(maxsize=1)
def artifact_store() -> ArtifactStore:
    return ArtifactStore()


@lru_cache(maxsize=1)
def provision_queue() -> TaskQueue:
    return TaskQueue(get_settings().provision_queue_url)


@lru_cache(maxsize=1)
def binding_queue() -> TaskQueue:
    return TaskQueue(get_settings().binding_queue_url)
