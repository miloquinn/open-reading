from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

from ..database import Database
from ..models import Release, utc_now


class DownloadRepository:
    def __init__(self, database: Database):
        self.database = database

    def record(
        self,
        release_id: str,
        *,
        request_ip: str,
        ip_hash: str,
        user_agent: str | None,
        source: str,
    ) -> Release | None:
        with self.database.transaction(immediate=True) as connection:
            self._purge_expired(connection)
            row = connection.execute(
                "SELECT * FROM releases WHERE id=? AND is_published=1", (release_id,)
            ).fetchone()
            if row is None:
                return None
            now = utc_now()
            connection.execute(
                "UPDATE releases SET download_count=download_count+1, updated_at=? WHERE id=?",
                (now, release_id),
            )
            connection.execute(
                """INSERT INTO download_events (
                    release_id, release_version, platform, architecture, channel,
                    source, request_ip, ip_hash, user_agent, occurred_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    release_id,
                    row["version"],
                    row["platform"],
                    row["architecture"],
                    row["channel"],
                    source,
                    request_ip,
                    ip_hash,
                    user_agent,
                    now,
                ),
            )
            refreshed = connection.execute(
                "SELECT * FROM releases WHERE id=?", (release_id,)
            ).fetchone()
        return Release.from_row(refreshed) if refreshed else None

    def summary(self, *, days: int = 30) -> dict[str, Any]:
        self.purge_expired()
        cutoff = (datetime.now(UTC) - timedelta(days=days)).isoformat()
        with self.database.connect() as connection:
            totals = connection.execute(
                """SELECT COUNT(*) AS downloads, COUNT(DISTINCT ip_hash) AS unique_ips
                FROM download_events WHERE occurred_at >= ?""",
                (cutoff,),
            ).fetchone()
            by_day = connection.execute(
                """SELECT substr(occurred_at, 1, 10) AS date,
                    COUNT(*) AS downloads,
                    COUNT(DISTINCT ip_hash) AS unique_ips
                FROM download_events
                WHERE occurred_at >= ?
                GROUP BY substr(occurred_at, 1, 10)
                ORDER BY date""",
                (cutoff,),
            ).fetchall()
            by_release = connection.execute(
                """SELECT release_id, release_version AS version, platform, architecture, channel,
                    COUNT(*) AS downloads,
                    COUNT(DISTINCT ip_hash) AS unique_ips
                FROM download_events
                WHERE occurred_at >= ?
                GROUP BY release_id, release_version, platform, architecture, channel
                ORDER BY downloads DESC, release_version DESC""",
                (cutoff,),
            ).fetchall()
            recent = connection.execute(
                """SELECT id, release_id, release_version AS version, platform, architecture,
                    source, request_ip, user_agent, occurred_at
                FROM download_events
                WHERE occurred_at >= ?
                ORDER BY occurred_at DESC
                LIMIT 100""",
                (cutoff,),
            ).fetchall()
        return {
            "period_days": days,
            "totals": {
                "downloads": int(totals["downloads"] if totals else 0),
                "unique_ips": int(totals["unique_ips"] if totals else 0),
            },
            "by_day": [dict(row) for row in by_day],
            "by_release": [dict(row) for row in by_release],
            "recent": [dict(row) for row in recent],
        }

    def purge_expired(self, *, retention_days: int = 30) -> int:
        with self.database.transaction(immediate=True) as connection:
            return self._purge_expired(connection, retention_days=retention_days)

    @staticmethod
    def _purge_expired(connection, *, retention_days: int = 30) -> int:
        cutoff = (datetime.now(UTC) - timedelta(days=retention_days)).isoformat()
        result = connection.execute(
            "DELETE FROM download_events WHERE occurred_at < ?", (cutoff,)
        )
        return int(result.rowcount)
