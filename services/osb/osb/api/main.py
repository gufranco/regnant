"""FastAPI application entrypoint for the OSB API."""

from __future__ import annotations

import structlog
import uvicorn
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from opentelemetry.instrumentation.botocore import BotocoreInstrumentor
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from prometheus_fastapi_instrumentator import Instrumentator

from ..config import get_settings
from ..exceptions import OsbError
from ..observability import setup as setup_observability
from .routes import router as v2_router

logger = structlog.get_logger(__name__)


def create_app() -> FastAPI:
    setup_observability()
    app = FastAPI(
        title="regnant Open Service Broker",
        version="0.1.0",
        docs_url="/docs",
        redoc_url=None,
    )

    @app.exception_handler(OsbError)
    async def handle_osb_error(_request: Request, exc: OsbError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"error": exc.error_code, "description": exc.message},
        )

    @app.get("/health", include_in_schema=False)
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    app.include_router(v2_router)

    Instrumentator(excluded_handlers=["/health", "/metrics"]).instrument(app).expose(app)
    FastAPIInstrumentor.instrument_app(app)
    BotocoreInstrumentor().instrument()
    return app


app = create_app()


def run() -> None:
    settings = get_settings()
    uvicorn.run(
        "osb.api.main:app",
        host=settings.host,
        port=settings.port,
        log_level=settings.log_level.lower(),
        access_log=False,
    )


if __name__ == "__main__":
    run()
