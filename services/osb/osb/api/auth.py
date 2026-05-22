"""HTTP Basic auth as required by the OSB API spec."""

from __future__ import annotations

import secrets
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBasic, HTTPBasicCredentials

from ..config import get_settings

_security = HTTPBasic()


def require_broker(
    credentials: Annotated[HTTPBasicCredentials, Depends(_security)],
) -> str:
    """Verify the request carries the broker credentials."""
    settings = get_settings()
    valid_user = secrets.compare_digest(credentials.username, settings.broker_username)
    valid_pass = secrets.compare_digest(credentials.password, settings.broker_password)
    if not (valid_user and valid_pass):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid broker credentials",
            headers={"WWW-Authenticate": "Basic"},
        )
    return credentials.username
