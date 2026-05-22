"""Jira-clone backend. In-memory issue/project/sprint store."""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timezone

import structlog
import uvicorn
from fastapi import FastAPI, HTTPException
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel
from opentelemetry import trace

logger = structlog.get_logger(__name__)

_BACKEND_NAME = os.getenv("BACKEND_NAME", "jira-clone")
_OTLP = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


class Project(BaseModel):
    id: str
    key: str
    name: str
    created_at: str


class Issue(BaseModel):
    id: str
    project_id: str
    summary: str
    status: str
    created_at: str


class Sprint(BaseModel):
    id: str
    project_id: str
    name: str
    state: str
    created_at: str


def _make_app() -> FastAPI:
    resource = Resource.create({"service.name": _BACKEND_NAME, "service.namespace": "regnant"})
    provider = TracerProvider(resource=resource)
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=_OTLP, insecure=True)))
    trace.set_tracer_provider(provider)

    app = FastAPI(title=f"regnant {_BACKEND_NAME}", version="0.1.0")
    FastAPIInstrumentor.instrument_app(app)
    Instrumentator(excluded_handlers=["/health", "/metrics"]).instrument(app).expose(app)

    projects: dict[str, Project] = {}
    issues: dict[str, Issue] = {}
    sprints: dict[str, Sprint] = {}

    @app.get("/health", include_in_schema=False)
    def health() -> dict[str, str]:
        return {"status": "ok", "backend": _BACKEND_NAME}

    @app.get("/projects", response_model=list[Project])
    def list_projects() -> list[Project]:
        return list(projects.values())

    @app.post("/projects", response_model=Project, status_code=201)
    def create_project(payload: dict[str, str]) -> Project:
        project = Project(
            id=str(uuid.uuid4()),
            key=payload.get("key", "REG"),
            name=payload.get("name", "Regnant Project"),
            created_at=_now(),
        )
        projects[project.id] = project
        return project

    @app.get("/issues", response_model=list[Issue])
    def list_issues(project_id: str | None = None) -> list[Issue]:
        items = issues.values()
        if project_id:
            items = [i for i in items if i.project_id == project_id]
        return list(items)

    @app.post("/issues", response_model=Issue, status_code=201)
    def create_issue(payload: dict[str, str]) -> Issue:
        project_id = payload.get("project_id")
        if project_id and project_id not in projects:
            raise HTTPException(status_code=404, detail="project not found")
        issue = Issue(
            id=str(uuid.uuid4()),
            project_id=project_id or "",
            summary=payload.get("summary", "untitled"),
            status=payload.get("status", "todo"),
            created_at=_now(),
        )
        issues[issue.id] = issue
        return issue

    @app.get("/sprints", response_model=list[Sprint])
    def list_sprints() -> list[Sprint]:
        return list(sprints.values())

    @app.post("/sprints", response_model=Sprint, status_code=201)
    def create_sprint(payload: dict[str, str]) -> Sprint:
        project_id = payload.get("project_id", "")
        sprint = Sprint(
            id=str(uuid.uuid4()),
            project_id=project_id,
            name=payload.get("name", "Sprint"),
            state=payload.get("state", "active"),
            created_at=_now(),
        )
        sprints[sprint.id] = sprint
        return sprint

    return app


app = _make_app()


def run() -> None:
    uvicorn.run(app, host="0.0.0.0", port=8080, access_log=False)


if __name__ == "__main__":
    run()
