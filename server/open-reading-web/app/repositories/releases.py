from __future__ import annotations

import json
from typing import Any

from ..database import Database
from ..models import AdminSession, Release, compare_versions, utc_now


class ReleaseRepository:
    def __init__(self, database: Database):
        self.database = database

    def create(self, release: Release, *, make_latest: bool = True) -> Release:
        with self.database.transaction(immediate=True) as connection:
            if make_latest:
                self._assert_latest_is_monotonic(connection, release)
                connection.execute(
                    """UPDATE releases SET is_latest=0, updated_at=?
                    WHERE platform=? AND architecture=? AND channel=?""",
                    (utc_now(), release.platform, release.architecture, release.channel),
                )
            connection.execute(
                """INSERT INTO releases (
                  id, platform, package_type, architecture, channel, version, build_number,
                  release_notes, stored_filename, original_filename, file_size, sha256,
                  download_count, github_release_url, mandatory, is_latest, is_published,
                  published_at, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    release.id,
                    release.platform,
                    release.package_type,
                    release.architecture,
                    release.channel,
                    release.version,
                    release.build_number,
                    release.release_notes,
                    release.stored_filename,
                    release.original_filename,
                    release.file_size,
                    release.sha256,
                    release.download_count,
                    release.github_release_url,
                    int(release.mandatory),
                    int(make_latest),
                    int(release.is_published),
                    release.published_at,
                    release.created_at,
                    release.updated_at,
                ),
            )
        found = self.get(release.id, include_unpublished=True)
        assert found is not None
        return found

    def get(self, release_id: str, *, include_unpublished: bool = False) -> Release | None:
        query = "SELECT * FROM releases WHERE id=?"
        params: list[Any] = [release_id]
        if not include_unpublished:
            query += " AND is_published=1"
        with self.database.connect() as connection:
            row = connection.execute(query, params).fetchone()
        return Release.from_row(row) if row else None

    def latest(
        self, platform: str | None = None, architecture: str | None = None, channel: str = "stable"
    ) -> list[Release]:
        clauses = ["is_latest=1", "is_published=1", "channel=?"]
        params: list[Any] = [channel]
        if platform:
            clauses.append("platform=?")
            params.append(platform)
        if architecture:
            clauses.append("architecture=?")
            params.append(architecture)
        query = f"""SELECT * FROM releases WHERE {" AND ".join(clauses)}
        ORDER BY platform, CASE architecture WHEN 'universal' THEN 0 ELSE 1 END, architecture"""
        with self.database.connect() as connection:
            rows = connection.execute(query, params).fetchall()
        return [Release.from_row(row) for row in rows]

    def list(
        self,
        *,
        platform: str | None = None,
        channel: str | None = None,
        architecture: str | None = None,
        limit: int = 50,
        offset: int = 0,
        include_unpublished: bool = False,
    ) -> tuple[list[Release], int]:
        clauses = ["1=1"]
        params: list[Any] = []
        if not include_unpublished:
            clauses.append("is_published=1")
        for column, value in (
            ("platform", platform),
            ("channel", channel),
            ("architecture", architecture),
        ):
            if value:
                clauses.append(f"{column}=?")
                params.append(value)
        where = " AND ".join(clauses)
        with self.database.connect() as connection:
            total = connection.execute(
                f"SELECT COUNT(*) FROM releases WHERE {where}", params
            ).fetchone()[0]
            rows = connection.execute(
                f"SELECT * FROM releases WHERE {where} ORDER BY published_at DESC LIMIT ? OFFSET ?",
                [*params, limit, offset],
            ).fetchall()
        return [Release.from_row(row) for row in rows], int(total)

    def set_latest(self, release_id: str) -> Release:
        with self.database.transaction(immediate=True) as connection:
            row = connection.execute(
                "SELECT * FROM releases WHERE id=? AND is_published=1", (release_id,)
            ).fetchone()
            if row is None:
                raise LookupError("发行版本不存在或已下架")
            self._assert_latest_is_monotonic(connection, Release.from_row(row))
            now = utc_now()
            connection.execute(
                """UPDATE releases SET is_latest=0, updated_at=?
                WHERE platform=? AND architecture=? AND channel=?""",
                (now, row["platform"], row["architecture"], row["channel"]),
            )
            connection.execute(
                "UPDATE releases SET is_latest=1, updated_at=? WHERE id=?", (now, release_id)
            )
        return self.get(release_id, include_unpublished=True)  # type: ignore[return-value]

    def find_identity(
        self,
        *,
        platform: str,
        architecture: str,
        channel: str,
        version: str,
        package_type: str,
    ) -> Release | None:
        with self.database.connect() as connection:
            row = connection.execute(
                """SELECT * FROM releases
                WHERE platform=? AND architecture=? AND channel=? AND version=?
                  AND package_type=? AND is_published=1
                ORDER BY created_at DESC LIMIT 1""",
                (platform, architecture, channel, version, package_type),
            ).fetchone()
        return Release.from_row(row) if row else None

    def create_many(
        self, releases: list[Release], *, activate_existing: list[str] | None = None
    ) -> list[Release]:
        activate_existing = activate_existing or []
        if not releases and not activate_existing:
            return []
        with self.database.transaction(immediate=True) as connection:
            now = utc_now()
            for release in releases:
                self._assert_latest_is_monotonic(connection, release)
                connection.execute(
                    """UPDATE releases SET is_latest=0, updated_at=?
                    WHERE platform=? AND architecture=? AND channel=?""",
                    (now, release.platform, release.architecture, release.channel),
                )
                connection.execute(
                    """INSERT INTO releases (
                      id, platform, package_type, architecture, channel, version, build_number,
                      release_notes, stored_filename, original_filename, file_size, sha256,
                      download_count, github_release_url, mandatory, is_latest, is_published,
                      published_at, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 1, ?, ?, ?)""",
                    (
                        release.id,
                        release.platform,
                        release.package_type,
                        release.architecture,
                        release.channel,
                        release.version,
                        release.build_number,
                        release.release_notes,
                        release.stored_filename,
                        release.original_filename,
                        release.file_size,
                        release.sha256,
                        release.download_count,
                        release.github_release_url,
                        int(release.mandatory),
                        release.published_at,
                        release.created_at,
                        release.updated_at,
                    ),
                )
            for release_id in activate_existing:
                row = connection.execute(
                    "SELECT * FROM releases WHERE id=? AND is_published=1", (release_id,)
                ).fetchone()
                if row is None:
                    raise LookupError("幂等导入引用的发行版本不存在或已下架")
                self._assert_latest_is_monotonic(connection, Release.from_row(row))
                connection.execute(
                    """UPDATE releases SET is_latest=0, updated_at=?
                    WHERE platform=? AND architecture=? AND channel=?""",
                    (now, row["platform"], row["architecture"], row["channel"]),
                )
                connection.execute(
                    "UPDATE releases SET is_latest=1, updated_at=? WHERE id=?",
                    (now, release_id),
                )
        return [
            item
            for release in releases
            if (item := self.get(release.id, include_unpublished=True)) is not None
        ]

    @staticmethod
    def _assert_latest_is_monotonic(connection: Any, release: Release) -> None:
        if release.channel != "stable":
            return
        rows = connection.execute(
            """SELECT version FROM releases
            WHERE platform=? AND architecture=? AND channel='stable'""",
            (release.platform, release.architecture),
        ).fetchall()
        newer = next(
            (
                row["version"]
                for row in rows
                if compare_versions(release.version, row["version"]) < 0
            ),
            None,
        )
        if newer is not None:
            raise ValueError(
                f"stable 版本不能回退: current={newer} requested={release.version}"
            )

    def unpublish(self, release_id: str) -> Release:
        with self.database.transaction(immediate=True) as connection:
            result = connection.execute(
                "UPDATE releases SET is_published=0, is_latest=0, updated_at=? WHERE id=?",
                (utc_now(), release_id),
            )
            if result.rowcount != 1:
                raise LookupError("发行版本不存在")
        return self.get(release_id, include_unpublished=True)  # type: ignore[return-value]

    def increment_download(self, release_id: str) -> Release | None:
        with self.database.transaction(immediate=True) as connection:
            connection.execute(
                "UPDATE releases SET download_count=download_count+1 WHERE id=? AND is_published=1",
                (release_id,),
            )
        return self.get(release_id)

    def platform_rows(self) -> list[dict[str, Any]]:
        with self.database.connect() as connection:
            rows = connection.execute("SELECT * FROM platforms ORDER BY sort_order").fetchall()
        return [
            {
                **dict(row),
                "key": row["slug"],
                "name": row["display_name"],
                "package_types": json.loads(row["package_types_json"]),
                "architectures": json.loads(row["architectures_json"]),
                "package_types_json": row["package_types_json"],
                "architectures_json": row["architectures_json"],
            }
            for row in rows
        ]

    def all(self, *, include_unpublished: bool = True) -> list[Release]:
        items, _ = self.list(limit=100_000, include_unpublished=include_unpublished)
        return items

    def total_download_count(self) -> int:
        with self.database.connect() as connection:
            value = connection.execute(
                "SELECT COALESCE(SUM(download_count), 0) FROM releases"
            ).fetchone()[0]
        return int(value)


class AuthRepository:
    def __init__(self, database: Database):
        self.database = database

    def create_oauth_state(self, state_hash: str, expires_at: str) -> None:
        now = utc_now()
        with self.database.transaction(immediate=True) as connection:
            connection.execute("DELETE FROM oauth_states WHERE expires_at <= ?", (now,))
            connection.execute(
                """DELETE FROM oauth_states WHERE state_hash IN (
                    SELECT state_hash FROM oauth_states ORDER BY created_at ASC
                    LIMIT MAX((SELECT COUNT(*) FROM oauth_states) - 999, 0)
                )"""
            )
            connection.execute(
                "INSERT INTO oauth_states VALUES (?, ?, ?)", (state_hash, expires_at, now)
            )

    def consume_oauth_state(self, state_hash: str) -> bool:
        with self.database.transaction(immediate=True) as connection:
            row = connection.execute(
                "SELECT state_hash FROM oauth_states WHERE state_hash=? AND expires_at>?",
                (state_hash, utc_now()),
            ).fetchone()
            connection.execute("DELETE FROM oauth_states WHERE state_hash=?", (state_hash,))
        return row is not None

    def create_session(
        self,
        session_hash: str,
        user_id: int,
        login: str,
        avatar_url: str | None,
        csrf_token: str,
        expires_at: str,
    ) -> None:
        now = utc_now()
        with self.database.transaction(immediate=True) as connection:
            connection.execute("DELETE FROM admin_sessions WHERE expires_at <= ?", (now,))
            connection.execute(
                "INSERT INTO admin_sessions VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (session_hash, user_id, login, avatar_url, csrf_token, now, expires_at, now),
            )

    def get_session(self, session_hash: str) -> AdminSession | None:
        now = utc_now()
        with self.database.transaction() as connection:
            row = connection.execute(
                "SELECT * FROM admin_sessions WHERE session_hash=? AND expires_at>?",
                (session_hash, now),
            ).fetchone()
            if row:
                connection.execute(
                    "UPDATE admin_sessions SET last_used_at=? WHERE session_hash=?",
                    (now, session_hash),
                )
        if not row:
            return None
        return AdminSession(
            row["github_user_id"],
            row["github_login"],
            row["avatar_url"],
            row["csrf_token"],
            row["expires_at"],
        )

    def delete_session(self, session_hash: str) -> None:
        with self.database.transaction() as connection:
            connection.execute("DELETE FROM admin_sessions WHERE session_hash=?", (session_hash,))

    def audit(
        self,
        event_type: str,
        *,
        user_id: int | None = None,
        login: str | None = None,
        request_ip: str | None = None,
        user_agent: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> None:
        with self.database.transaction() as connection:
            connection.execute(
                """INSERT INTO audit_events
                (event_type, github_user_id, github_login, request_ip, user_agent,
                 metadata_json, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)""",
                (
                    event_type,
                    user_id,
                    login,
                    request_ip,
                    user_agent,
                    json.dumps(metadata or {}, ensure_ascii=False),
                    utc_now(),
                ),
            )
