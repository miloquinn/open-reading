from __future__ import annotations

import hashlib
import secrets
import time
from collections import OrderedDict, deque
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from threading import Lock
from urllib.parse import urlencode

import httpx
from fastapi import HTTPException, Request, status

from ..config import Settings
from ..models import AdminSession
from ..repositories.releases import AuthRepository

SESSION_COOKIE = "open_reading_admin"
OAUTH_STATE_COOKIE = "open_reading_oauth_state"


@dataclass
class _RateLimitBucket:
    events: deque[float]
    window_seconds: int


class SlidingWindowLimiter:
    def __init__(
        self,
        *,
        max_keys: int = 8192,
        sweep_interval: int = 256,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        if max_keys <= 0 or sweep_interval <= 0:
            raise ValueError("限流器容量和清理间隔必须大于零")
        self._events: OrderedDict[str, _RateLimitBucket] = OrderedDict()
        self._max_keys = max_keys
        self._sweep_interval = sweep_interval
        self._clock = clock
        self._operations = 0
        self._lock = Lock()

    def require(self, key: str, *, limit: int, window_seconds: int) -> None:
        if limit <= 0 or window_seconds <= 0:
            raise ValueError("限流次数和窗口必须大于零")
        now = self._clock()
        with self._lock:
            self._operations += 1
            if self._operations % self._sweep_interval == 0:
                self._remove_expired(now)

            bucket = self._events.get(key)
            if bucket is None:
                if len(self._events) >= self._max_keys:
                    self._remove_expired(now)
                if len(self._events) >= self._max_keys:
                    self._events.popitem(last=False)
                bucket = _RateLimitBucket(deque(), window_seconds)
                self._events[key] = bucket
            elif bucket.window_seconds != window_seconds:
                raise ValueError("同一限流 key 不能使用不同时间窗口")
            else:
                self._events.move_to_end(key)

            cutoff = now - window_seconds
            while bucket.events and bucket.events[0] <= cutoff:
                bucket.events.popleft()
            if len(bucket.events) >= limit:
                raise HTTPException(
                    status.HTTP_429_TOO_MANY_REQUESTS,
                    "请求过于频繁，请稍后再试",
                )
            bucket.events.append(now)

    @property
    def tracked_key_count(self) -> int:
        with self._lock:
            return len(self._events)

    def _remove_expired(self, now: float) -> None:
        for key, bucket in list(self._events.items()):
            cutoff = now - bucket.window_seconds
            while bucket.events and bucket.events[0] <= cutoff:
                bucket.events.popleft()
            if not bucket.events:
                del self._events[key]


def token_hash(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


class AuthService:
    def __init__(self, settings: Settings, repository: AuthRepository):
        self.settings = settings
        self.repository = repository

    def begin_login(self) -> tuple[str, str]:
        if not self.settings.github_client_id or not self.settings.github_client_secret:
            raise RuntimeError("GitHub OAuth 尚未配置")
        state = secrets.token_urlsafe(32)
        expires = datetime.now(UTC) + timedelta(minutes=self.settings.oauth_state_minutes)
        self.repository.create_oauth_state(token_hash(state), expires.isoformat())
        url = "https://github.com/login/oauth/authorize?" + urlencode(
            {
                "client_id": self.settings.github_client_id,
                "redirect_uri": self.settings.github_callback_url,
                "scope": "read:user",
                "state": state,
            }
        )
        return url, state

    async def finish_login(
        self, code: str, state: str, cookie_state: str | None
    ) -> tuple[str, AdminSession]:
        if not cookie_state or not secrets.compare_digest(state, cookie_state):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "OAuth state 校验失败")
        if not self.repository.consume_oauth_state(token_hash(state)):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "OAuth state 已失效或已使用")
        async with httpx.AsyncClient(timeout=15) as client:
            token_response = await client.post(
                "https://github.com/login/oauth/access_token",
                headers={"Accept": "application/json"},
                data={
                    "client_id": self.settings.github_client_id,
                    "client_secret": self.settings.github_client_secret,
                    "code": code,
                    "redirect_uri": self.settings.github_callback_url,
                },
            )
            token_response.raise_for_status()
            access_token = token_response.json().get("access_token")
            if not access_token:
                raise HTTPException(status.HTTP_401_UNAUTHORIZED, "GitHub 授权失败")
            user_response = await client.get(
                "https://api.github.com/user",
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Accept": "application/vnd.github+json",
                },
            )
            user_response.raise_for_status()
            user = user_response.json()
        user_id, login = int(user["id"]), str(user["login"])
        id_matches = (
            self.settings.github_admin_id is not None and user_id == self.settings.github_admin_id
        )
        login_matches = login.casefold() == self.settings.github_admin_login.casefold()
        if not (id_matches and login_matches):
            self.repository.audit("login_denied", user_id=user_id, login=login)
            raise HTTPException(status.HTTP_403_FORBIDDEN, "该 GitHub 账号没有管理权限")
        raw_session = secrets.token_urlsafe(48)
        csrf_token = secrets.token_urlsafe(32)
        expires = datetime.now(UTC) + timedelta(hours=self.settings.session_hours)
        self.repository.create_session(
            token_hash(raw_session),
            user_id,
            login,
            user.get("avatar_url"),
            csrf_token,
            expires.isoformat(),
        )
        session = AdminSession(
            user_id, login, user.get("avatar_url"), csrf_token, expires.isoformat()
        )
        self.repository.audit("login_success", user_id=user_id, login=login)
        return raw_session, session

    def session_for_request(self, request: Request) -> AdminSession | None:
        raw_session = request.cookies.get(SESSION_COOKIE)
        return self.repository.get_session(token_hash(raw_session)) if raw_session else None

    def require_session(self, request: Request) -> AdminSession:
        session = self.session_for_request(request)
        if session is None:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "请先登录")
        return session

    def require_csrf(
        self, request: Request, supplied_token: str | None, session: AdminSession
    ) -> None:
        if not supplied_token or not secrets.compare_digest(supplied_token, session.csrf_token):
            self.repository.audit(
                "csrf_rejected", user_id=session.github_user_id, login=session.github_login
            )
            raise HTTPException(status.HTTP_403_FORBIDDEN, "CSRF 校验失败")

    def logout(self, raw_session: str | None) -> None:
        if raw_session:
            self.repository.delete_session(token_hash(raw_session))
