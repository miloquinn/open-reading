from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from fastapi import HTTPException

from app.config import Settings
from app.database import Database
from app.repositories.releases import AuthRepository
from app.services.auth import AuthService, SlidingWindowLimiter, token_hash


class _Response:
    def __init__(self, payload: dict) -> None:
        self.payload = payload

    def raise_for_status(self) -> None:
        return None

    def json(self) -> dict:
        return self.payload


class _GitHubClient:
    user = {"id": 12345678, "login": "miloquinn", "avatar_url": None}

    def __init__(self, **_: object) -> None:
        pass

    async def __aenter__(self) -> "_GitHubClient":
        return self

    async def __aexit__(self, *_: object) -> None:
        return None

    async def post(self, *_: object, **__: object) -> _Response:
        return _Response({"access_token": "temporary-token"})

    async def get(self, *_: object, **__: object) -> _Response:
        return _Response(self.user)


def _service(tmp_path: Path) -> tuple[AuthService, AuthRepository]:
    settings = Settings(
        base_url="http://testserver",
        database_path=tmp_path / "releases.db",
        release_root=tmp_path / "releases",
        upload_temp_root=tmp_path / "releases" / ".uploads",
        github_client_id="client-id",
        github_client_secret="client-secret",
        github_admin_id=12345678,
        github_admin_login="miloquinn",
        github_repository="miloquinn/open-reading",
        session_hours=12,
        oauth_state_minutes=10,
        max_upload_bytes=1024,
        secure_cookies=False,
    )
    database = Database(settings.database_path)
    database.initialize()
    repository = AuthRepository(database)
    return AuthService(settings, repository), repository


@pytest.mark.asyncio
async def test_oauth_accepts_only_matching_numeric_id_and_login(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    service, repository = _service(tmp_path)
    state = "one-time-state"
    expires = (datetime.now(UTC) + timedelta(minutes=5)).isoformat()
    repository.create_oauth_state(token_hash(state), expires)
    monkeypatch.setattr("app.services.auth.httpx.AsyncClient", _GitHubClient)

    raw_session, session = await service.finish_login("code", state, state)

    assert raw_session
    assert session.github_user_id == 12345678
    assert session.github_login == "miloquinn"
    assert repository.consume_oauth_state(token_hash(state)) is False


@pytest.mark.asyncio
async def test_oauth_rejects_same_login_with_wrong_numeric_id(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    service, repository = _service(tmp_path)
    state = "one-time-state"
    expires = (datetime.now(UTC) + timedelta(minutes=5)).isoformat()
    repository.create_oauth_state(token_hash(state), expires)
    monkeypatch.setattr(
        _GitHubClient,
        "user",
        {"id": 87654321, "login": "miloquinn", "avatar_url": None},
    )
    monkeypatch.setattr("app.services.auth.httpx.AsyncClient", _GitHubClient)

    with pytest.raises(HTTPException) as error:
        await service.finish_login("code", state, state)

    assert error.value.status_code == 403


def test_rate_limiter_rejects_bursts() -> None:
    limiter = SlidingWindowLimiter()
    limiter.require("login:127.0.0.1", limit=2, window_seconds=60)
    limiter.require("login:127.0.0.1", limit=2, window_seconds=60)

    with pytest.raises(HTTPException) as error:
        limiter.require("login:127.0.0.1", limit=2, window_seconds=60)

    assert error.value.status_code == 429


def test_rate_limiter_bounds_high_cardinality_and_cleans_expired_keys() -> None:
    now = [1000.0]
    limiter = SlidingWindowLimiter(
        max_keys=64,
        sweep_interval=16,
        clock=lambda: now[0],
    )

    for index in range(10_000):
        limiter.require(
            f"metadata:2001:db8::{index}",
            limit=120,
            window_seconds=60,
        )
    assert limiter.tracked_key_count == 64

    now[0] += 61
    limiter.require("metadata:2001:db8::fresh", limit=120, window_seconds=60)
    assert limiter.tracked_key_count == 1


def test_rate_limiter_check_and_record_are_atomic_under_concurrency() -> None:
    limiter = SlidingWindowLimiter(clock=lambda: 1000.0)

    def attempt(_index: int) -> bool:
        try:
            limiter.require("download:203.0.113.7", limit=25, window_seconds=3600)
        except HTTPException as error:
            assert error.status_code == 429
            return False
        return True

    with ThreadPoolExecutor(max_workers=32) as executor:
        results = list(executor.map(attempt, range(200)))

    assert sum(results) == 25
