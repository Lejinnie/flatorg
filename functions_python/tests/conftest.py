"""Pytest configuration and shared fixtures.

Fixture helpers live in helpers.py to allow direct import from test modules.
"""

from __future__ import annotations

# Re-export so conftest stays available via pytest fixture discovery while
# test modules can also import helpers directly.
from tests.helpers import (  # noqa: F401
    DEFAULT_FLAT,
    FUTURE_DATE,
    build_full_scenario,
    make_person,
    make_task,
)
