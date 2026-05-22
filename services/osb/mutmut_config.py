"""mutmut configuration for the OSB service.

Run from this directory:

    mutmut run --paths-to-mutate=osb --runner='pytest -x -q'
    mutmut results
    mutmut html

Threshold: 75% of mutants killed before the change can land.
"""

from __future__ import annotations

import os
import re

EXCLUDE_LINES = re.compile(r"^\s*(import|from|@|#|\"\"\"|\'\'\')")


def pre_mutation(context):
    # Skip lines that look like imports, decorators, comments, or
    # docstring openers.
    line = context.current_source_line
    if EXCLUDE_LINES.match(line):
        context.skip = True
    # Skip the config + observability modules; their behavior is
    # mostly env-driven and not amenable to mutation.
    if "config.py" in context.filename or "observability.py" in context.filename:
        context.skip = True


def post_mutation(context):
    # Honor a CI flag that switches to a faster runner with less output.
    if os.getenv("MUTMUT_FAST") == "1":
        context.config.test_command = "pytest -x -q --no-cov"
