"""regnant SDK: typed Python client for the OSB API.

Hand-written for now; once openapi-python-client is wired into CI the
client module is regenerated and this `__init__` re-exports the same
symbols.
"""

from .client import RegnantClient
from .models import (
    BindCredentials,
    BindRequest,
    BindResponse,
    Catalog,
    CatalogPlan,
    CatalogService,
    LastOperation,
    ProvisionRequest,
    ProvisionResponse,
)

__all__ = [
    "BindCredentials",
    "BindRequest",
    "BindResponse",
    "Catalog",
    "CatalogPlan",
    "CatalogService",
    "LastOperation",
    "ProvisionRequest",
    "ProvisionResponse",
    "RegnantClient",
]
__version__ = "0.1.0"
