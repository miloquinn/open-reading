from __future__ import annotations

import hashlib
import hmac
import ipaddress

from fastapi import Request

from ..config import Settings
from ..models import Release
from ..repositories.downloads import DownloadRepository


class DownloadStatsService:
    def __init__(self, settings: Settings, repository: DownloadRepository):
        configured = settings.download_stats_secret.strip()
        if settings.base_url.startswith("https://") and len(configured) < 32:
            raise RuntimeError(
                "OPEN_READING_DOWNLOAD_STATS_SECRET must contain at least 32 characters"
            )
        self._secret = (
            configured.encode("utf-8")
            if configured
            else f"development-only:{settings.database_path.resolve()}".encode()
        )
        self.repository = repository

    def record(self, request: Request, release_id: str, *, source: str) -> Release | None:
        client_ip = self._normalized_client_ip(request)
        user_agent = request.headers.get("user-agent", "").strip()[:512]
        return self.repository.record(
            release_id,
            request_ip=client_ip,
            ip_hash=self._hash(f"ip:{client_ip}"),
            user_agent=user_agent or None,
            source=source,
        )

    def summary(self, *, days: int) -> dict:
        return self.repository.summary(days=days)

    def purge_expired(self) -> int:
        return self.repository.purge_expired(retention_days=30)

    def _hash(self, value: str) -> str:
        return hmac.new(self._secret, value.encode("utf-8"), hashlib.sha256).hexdigest()

    @staticmethod
    def _normalized_client_ip(request: Request) -> str:
        raw = (request.client.host if request.client else "unknown").strip()
        try:
            address = ipaddress.ip_address(raw)
        except ValueError:
            return "unknown"
        if isinstance(address, ipaddress.IPv6Address) and address.ipv4_mapped:
            return str(address.ipv4_mapped)
        return address.compressed
