"""Confluence-clone backend. In-memory pages/spaces/labels store."""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timezone

import structlog
import uvicorn
from fastapi import FastAPI, HTTPException
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel

logger = structlog.get_logger(__name__)

_BACKEND_NAME = os.getenv("BACKEND_NAME", "confluence-clone")
_OTLP = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


class Space(BaseModel):
    id: str
    key: str
    name: str
    created_at: str


class Page(BaseModel):
    id: str
    space_id: str
    title: str
    content: str
    created_at: str


class Label(BaseModel):
    id: str
    name: str
    color: str


def _make_app() -> FastAPI:
    resource = Resource.create({"service.name": _BACKEND_NAME, "service.namespace": "regnant"})
    provider = TracerProvider(resource=resource)
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=_OTLP, insecure=True)))
    trace.set_tracer_provider(provider)

    app = FastAPI(title=f"regnant {_BACKEND_NAME}", version="0.1.0")
    FastAPIInstrumentor.instrument_app(app)
    Instrumentator(excluded_handlers=["/health", "/metrics"]).instrument(app).expose(app)

    spaces: dict[str, Space] = {}
    pages: dict[str, Page] = {}
    labels: dict[str, Label] = {}

    @app.get("/health", include_in_schema=False)
    def health() -> dict[str, str]:
        return {"status": "ok", "backend": _BACKEND_NAME}

    @app.get("/spaces", response_model=list[Space])
    def list_spaces() -> list[Space]:
        return list(spaces.values())

    @app.post("/spaces", response_model=Space, status_code=201)
    def create_space(payload: dict[str, str]) -> Space:
        space = Space(
            id=str(uuid.uuid4()),
            key=payload.get("key", "REG"),
            name=payload.get("name", "Regnant Space"),
            created_at=_now(),
        )
        spaces[space.id] = space
        return space

    @app.get("/pages", response_model=list[Page])
    def list_pages(space_id: str | None = None) -> list[Page]:
        items = pages.values()
        if space_id:
            items = [p for p in items if p.space_id == space_id]
        return list(items)

    @app.post("/pages", response_model=Page, status_code=201)
    def create_page(payload: dict[str, str]) -> Page:
        space_id = payload.get("space_id")
        if space_id and space_id not in spaces:
            raise HTTPException(status_code=404, detail="space not found")
        page = Page(
            id=str(uuid.uuid4()),
            space_id=space_id or "",
            title=payload.get("title", "untitled"),
            content=payload.get("content", ""),
            created_at=_now(),
        )
        pages[page.id] = page
        return page

    @app.get("/labels", response_model=list[Label])
    def list_labels() -> list[Label]:
        return list(labels.values())

    @app.post("/labels", response_model=Label, status_code=201)
    def create_label(payload: dict[str, str]) -> Label:
        label = Label(
            id=str(uuid.uuid4()),
            name=payload.get("name", "untitled"),
            color=payload.get("color", "#888"),
        )
        labels[label.id] = label
        return label

    return app


app = _make_app()


def run() -> None:
    uvicorn.run(app, host="0.0.0.0", port=8080, access_log=False)


if __name__ == "__main__":
    run()
