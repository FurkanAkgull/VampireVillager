import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.repositories.session_repository import session_repository
from main import app


@pytest.fixture(autouse=True)
def _fast_timers_and_clean_state():
    """Every test gets short phase timers and a clean in-memory store."""
    orig_night, orig_day = settings.night_seconds, settings.day_seconds
    orig_resolution_delay = settings.night_resolution_delay_seconds
    settings.night_seconds = 1
    settings.day_seconds = 1
    settings.night_resolution_delay_seconds = 0  # tests that need the real delay set it themselves
    session_repository._sessions.clear()
    yield
    settings.night_seconds, settings.day_seconds = orig_night, orig_day
    settings.night_resolution_delay_seconds = orig_resolution_delay
    session_repository._sessions.clear()


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c
