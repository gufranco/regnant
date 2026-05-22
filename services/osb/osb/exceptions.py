"""Domain exceptions. The API layer maps these to HTTP responses."""

from __future__ import annotations


class OsbError(Exception):
    """Base class for OSB domain errors."""

    status_code: int = 500
    error_code: str = "ServerError"

    def __init__(self, message: str, *, error_code: str | None = None) -> None:
        super().__init__(message)
        self.message = message
        if error_code is not None:
            self.error_code = error_code


class InstanceNotFound(OsbError):
    status_code = 404
    error_code = "InstanceNotFound"


class BindingNotFound(OsbError):
    status_code = 404
    error_code = "BindingNotFound"


class Conflict(OsbError):
    status_code = 409
    error_code = "Conflict"


class AsyncRequired(OsbError):
    status_code = 422
    error_code = "AsyncRequired"


class ConcurrencyError(OsbError):
    status_code = 422
    error_code = "ConcurrencyError"


class BadRequest(OsbError):
    status_code = 400
    error_code = "BadRequest"


class Unauthorized(OsbError):
    status_code = 401
    error_code = "Unauthorized"
