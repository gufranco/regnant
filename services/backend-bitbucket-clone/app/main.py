"""Bitbucket-clone backend. In-memory repos/pullrequests/branches store."""

from __future__ import annotations

import os
import uuid
from datetime import UTC, datetime

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

_BACKEND_NAME = os.getenv("BACKEND_NAME", "bitbucket-clone")
_OTLP = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317")


def _now() -> str:
    return datetime.now(UTC).isoformat()


class Repo(BaseModel):
    id: str
    workspace: str
    slug: str
    default_branch: str
    created_at: str


class PullRequest(BaseModel):
    id: str
    repo_id: str
    title: str
    state: str
    source_branch: str
    target_branch: str
    created_at: str


class Branch(BaseModel):
    name: str
    repo_id: str
    commit_sha: str


def _make_app() -> FastAPI:
    resource = Resource.create({"service.name": _BACKEND_NAME, "service.namespace": "regnant"})
    provider = TracerProvider(resource=resource)
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=_OTLP, insecure=True)))
    trace.set_tracer_provider(provider)

    app = FastAPI(title=f"regnant {_BACKEND_NAME}", version="0.1.0")
    FastAPIInstrumentor.instrument_app(app)
    Instrumentator(excluded_handlers=["/health", "/metrics"]).instrument(app).expose(app)

    repos: dict[str, Repo] = {}
    prs: dict[str, PullRequest] = {}
    branches: dict[tuple[str, str], Branch] = {}

    @app.get("/health", include_in_schema=False)
    def health() -> dict[str, str]:
        return {"status": "ok", "backend": _BACKEND_NAME}

    @app.get("/repos", response_model=list[Repo])
    def list_repos() -> list[Repo]:
        return list(repos.values())

    @app.post("/repos", response_model=Repo, status_code=201)
    def create_repo(payload: dict[str, str]) -> Repo:
        repo = Repo(
            id=str(uuid.uuid4()),
            workspace=payload.get("workspace", "regnant"),
            slug=payload.get("slug", "repo"),
            default_branch=payload.get("default_branch", "main"),
            created_at=_now(),
        )
        repos[repo.id] = repo
        return repo

    @app.get("/pullrequests", response_model=list[PullRequest])
    def list_pullrequests(repo_id: str | None = None) -> list[PullRequest]:
        items = prs.values()
        if repo_id:
            items = [p for p in items if p.repo_id == repo_id]
        return list(items)

    @app.post("/pullrequests", response_model=PullRequest, status_code=201)
    def create_pullrequest(payload: dict[str, str]) -> PullRequest:
        repo_id = payload.get("repo_id", "")
        if repo_id and repo_id not in repos:
            raise HTTPException(status_code=404, detail="repo not found")
        pr = PullRequest(
            id=str(uuid.uuid4()),
            repo_id=repo_id,
            title=payload.get("title", "untitled"),
            state=payload.get("state", "open"),
            source_branch=payload.get("source_branch", "feature"),
            target_branch=payload.get("target_branch", "main"),
            created_at=_now(),
        )
        prs[pr.id] = pr
        return pr

    @app.get("/branches", response_model=list[Branch])
    def list_branches(repo_id: str | None = None) -> list[Branch]:
        items = branches.values()
        if repo_id:
            items = [b for b in items if b.repo_id == repo_id]
        return list(items)

    @app.post("/branches", response_model=Branch, status_code=201)
    def create_branch(payload: dict[str, str]) -> Branch:
        repo_id = payload.get("repo_id", "")
        if repo_id and repo_id not in repos:
            raise HTTPException(status_code=404, detail="repo not found")
        branch = Branch(
            name=payload.get("name", "main"),
            repo_id=repo_id,
            commit_sha=payload.get("commit_sha", "0000000"),
        )
        branches[(repo_id, branch.name)] = branch
        return branch

    return app


app = _make_app()


def run() -> None:
    uvicorn.run(app, host="0.0.0.0", port=8080, access_log=False)


if __name__ == "__main__":
    run()
