"""Chaos: kill a random Envoy container and assert the platform recovers
within 30 seconds. Marked `chaos` so the regular suite skips it."""

from __future__ import annotations

import random
import subprocess
import time

import httpx
import pytest
from tenacity import retry, stop_after_attempt, wait_fixed


@pytest.mark.chaos
def test_envoy_kill_self_heals(envoy_url: str) -> None:
    # Arrange: choose a random Envoy.
    targets = ["envoy-1", "envoy-2", "envoy-3"]
    victim = random.choice(targets)  # noqa: S311

    # Sanity check that the stack is up before we start killing things.
    health = httpx.get(f"{envoy_url}/health", verify=False, timeout=5.0)
    assert health.status_code in {200, 401, 403, 404, 503}

    # Act: kill the container.
    subprocess.run(  # noqa: S603, S607
        ["docker", "compose", "kill", "-s", "SIGKILL", victim],
        check=True,
    )

    started = time.monotonic()

    @retry(stop=stop_after_attempt(15), wait=wait_fixed(2))
    def _await_recovery() -> None:
        response = httpx.get(f"{envoy_url}/health", verify=False, timeout=2.0)
        assert response.status_code in {200, 401, 403, 404, 503}

    _await_recovery()
    elapsed = time.monotonic() - started

    # Assert: NLB should re-route within 30 seconds; bring the container back.
    subprocess.run(["docker", "compose", "up", "-d", victim], check=True)  # noqa: S603, S607
    assert elapsed < 30.0, f"recovery took {elapsed:.1f}s"
