from __future__ import annotations

import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from .config import Settings
from .models import PLATFORM_PRESETS

SCHEMA = """
CREATE TABLE IF NOT EXISTS platforms (
    slug TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    package_types_json TEXT NOT NULL,
    architectures_json TEXT NOT NULL,
    sort_order INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS releases (
    id TEXT PRIMARY KEY,
    platform TEXT NOT NULL REFERENCES platforms(slug),
    package_type TEXT NOT NULL,
    architecture TEXT NOT NULL,
    channel TEXT NOT NULL CHECK(channel IN ('stable', 'beta', 'nightly')),
    version TEXT NOT NULL,
    build_number TEXT,
    release_notes TEXT NOT NULL,
    stored_filename TEXT NOT NULL,
    original_filename TEXT NOT NULL,
    file_size INTEGER NOT NULL CHECK(file_size >= 0),
    sha256 TEXT NOT NULL,
    download_count INTEGER NOT NULL DEFAULT 0,
    github_release_url TEXT,
    mandatory INTEGER NOT NULL DEFAULT 0 CHECK(mandatory IN (0, 1)),
    is_latest INTEGER NOT NULL DEFAULT 0 CHECK(is_latest IN (0, 1)),
    is_published INTEGER NOT NULL DEFAULT 1 CHECK(is_published IN (0, 1)),
    published_at TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS releases_one_latest
ON releases(platform, architecture, channel) WHERE is_latest = 1 AND is_published = 1;
CREATE INDEX IF NOT EXISTS releases_lookup
ON releases(platform, channel, architecture, is_published, published_at DESC);

CREATE TABLE IF NOT EXISTS download_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    release_id TEXT NOT NULL REFERENCES releases(id),
    release_version TEXT NOT NULL,
    platform TEXT NOT NULL,
    architecture TEXT NOT NULL,
    channel TEXT NOT NULL,
    source TEXT NOT NULL,
    request_ip TEXT NOT NULL,
    ip_hash TEXT NOT NULL CHECK(length(ip_hash) = 64),
    user_agent TEXT,
    occurred_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS download_events_occurred_at
ON download_events(occurred_at);
CREATE INDEX IF NOT EXISTS download_events_release
ON download_events(release_id, occurred_at);
CREATE INDEX IF NOT EXISTS download_events_unique_ip
ON download_events(ip_hash, occurred_at);

CREATE TABLE IF NOT EXISTS oauth_states (
    state_hash TEXT PRIMARY KEY,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS admin_sessions (
    session_hash TEXT PRIMARY KEY,
    github_user_id INTEGER NOT NULL,
    github_login TEXT NOT NULL,
    avatar_url TEXT,
    csrf_token TEXT NOT NULL,
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    last_used_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS audit_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL,
    github_user_id INTEGER,
    github_login TEXT,
    request_ip TEXT,
    user_agent TEXT,
    metadata_json TEXT NOT NULL DEFAULT '{}',
    created_at TEXT NOT NULL
);
"""


class Database:
    def __init__(self, path: Path):
        self.path = path

    def connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path, timeout=30, isolation_level=None)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA busy_timeout = 30000")
        return connection

    @contextmanager
    def transaction(self, *, immediate: bool = False) -> Iterator[sqlite3.Connection]:
        connection = self.connect()
        try:
            connection.execute("BEGIN IMMEDIATE" if immediate else "BEGIN")
            yield connection
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    def initialize(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.connect() as connection:
            connection.execute("PRAGMA journal_mode = WAL")
            connection.execute("PRAGMA synchronous = FULL")
            connection.executescript(SCHEMA)
            release_columns = {
                row["name"] for row in connection.execute("PRAGMA table_info(releases)")
            }
            if "mandatory" not in release_columns:
                connection.execute(
                    "ALTER TABLE releases ADD COLUMN mandatory INTEGER NOT NULL DEFAULT 0"
                )
            for preset in PLATFORM_PRESETS.values():
                connection.execute(
                    """INSERT INTO platforms
                    (slug, display_name, package_types_json, architectures_json, sort_order)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(slug) DO UPDATE SET
                      display_name=excluded.display_name,
                      package_types_json=excluded.package_types_json,
                      architectures_json=excluded.architectures_json,
                      sort_order=excluded.sort_order""",
                    preset.as_db_tuple(),
                )


def build_database(settings: Settings) -> Database:
    return Database(settings.database_path)
