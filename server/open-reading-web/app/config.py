from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path


def _bool_env(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    base_url: str
    database_path: Path
    release_root: Path
    upload_temp_root: Path
    github_client_id: str
    github_client_secret: str
    github_admin_id: int | None
    github_admin_login: str
    github_repository: str
    session_hours: int
    oauth_state_minutes: int
    max_upload_bytes: int
    secure_cookies: bool
    download_stats_secret: str = ""
    android_cert_sha256: str = ""

    @property
    def github_callback_url(self) -> str:
        return f"{self.base_url.rstrip('/')}/admin/callback"

    @classmethod
    def from_env(cls) -> Settings:
        data_root = Path(os.getenv("OPEN_READING_DATA_ROOT", "/srv/open-reading/data"))
        release_root = Path(os.getenv("OPEN_READING_RELEASE_ROOT", "/srv/open-reading/releases"))
        admin_id = os.getenv("GITHUB_ADMIN_ID", "").strip()
        return cls(
            base_url=os.getenv("OPEN_READING_BASE_URL", "http://127.0.0.1:3002").rstrip("/"),
            database_path=Path(os.getenv("OPEN_READING_DATABASE", str(data_root / "releases.db"))),
            release_root=release_root,
            upload_temp_root=Path(
                os.getenv("OPEN_READING_UPLOAD_TEMP", str(release_root / ".uploads"))
            ),
            github_client_id=os.getenv("GITHUB_CLIENT_ID", ""),
            github_client_secret=os.getenv("GITHUB_CLIENT_SECRET", ""),
            github_admin_id=int(admin_id) if admin_id else None,
            github_admin_login=os.getenv("GITHUB_ADMIN_LOGIN", ""),
            github_repository=os.getenv("GITHUB_REPOSITORY", "miloquinn/open-reading"),
            session_hours=int(os.getenv("OPEN_READING_SESSION_HOURS", "12")),
            oauth_state_minutes=int(os.getenv("OPEN_READING_OAUTH_STATE_MINUTES", "10")),
            max_upload_bytes=int(os.getenv("OPEN_READING_MAX_UPLOAD_BYTES", str(2 * 1024**3))),
            secure_cookies=_bool_env("OPEN_READING_SECURE_COOKIES", True),
            download_stats_secret=os.getenv("OPEN_READING_DOWNLOAD_STATS_SECRET", ""),
            android_cert_sha256=os.getenv("OPEN_READING_ANDROID_CERT_SHA256", ""),
        )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings.from_env()
