import hashlib
import json
import uuid
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.database import Database
from app.repositories.releases import ReleaseRepository
from app.services.auth import SESSION_COOKIE, token_hash
from app.services.release_import import ReleaseImportService


class _FakeAndroidVerifier:
    def __init__(self, actual_code: str = "14119"):
        self.actual_code = actual_code

    def verify(self, _path: Path, *, version_name: str, version_code: str) -> None:
        if version_name != "2.2.0" or version_code != self.actual_code:
            raise ValueError("APK versionCode 不一致")


class _FakeGitHubVerifier:
    def verify_bundle(self, *_args, **_kwargs) -> None:
        return None


def _import_service(settings: Settings, repository: ReleaseRepository) -> ReleaseImportService:
    return ReleaseImportService(
        settings,
        repository,
        android_verifier=_FakeAndroidVerifier(),
        github_verifier=_FakeGitHubVerifier(),
    )


def _authenticate(client: TestClient) -> None:
    raw_session = f"download-stats-admin-session-{uuid.uuid4()}"
    expires = (datetime.now(UTC) + timedelta(hours=1)).isoformat()
    client.app.state.auth_repository.create_session(
        token_hash(raw_session),
        12345678,
        "miloquinn",
        None,
        "csrf-token",
        expires,
    )
    client.cookies.set(SESSION_COOKIE, raw_session)


def _upload_android(client: TestClient, *, version: str = "2.2.0") -> dict:
    _authenticate(client)
    payload = b"PK\x03\x04android-release-payload"
    response = client.post(
        "/admin/releases/new",
        data={
            "platform": "android",
            "package_type": "apk",
            "architecture": "arm64-v8a",
            "channel": "stable",
            "version": version,
            "build_number": "14119",
            "release_notes": "Tablet layout and updater improvements.",
            "github_release_url": (
                f"https://github.com/miloquinn/open-reading/releases/tag/v{version}"
            ),
            "csrf_token": "csrf-token",
            "set_latest": "true",
        },
        files={
            "file": (
                "OpenReading-Android-arm64-v8a.apk",
                payload,
                "application/vnd.android.package-archive",
            )
        },
        follow_redirects=False,
    )
    assert response.status_code == 303
    return {"payload": payload}


def test_v1_latest_returns_direct_android_object_and_accepts_abi(client: TestClient) -> None:
    upload = _upload_android(client)

    response = client.get(
        "/api/v1/releases/latest",
        params={"platform": "android", "abi": "arm64-v8a", "channel": "stable"},
    )

    assert response.status_code == 200
    assert response.headers["cache-control"] == "no-store"
    body = response.json()
    expected_download_url = body["download_url"]
    expected_published_at = body["published_at"]
    assert body == {
        "schema_version": 1,
        "version": "2.2.0",
        "build_number": "14119",
        "platform": "android",
        "architecture": "arm64-v8a",
        "package_type": "apk",
        "channel": "stable",
        "release_notes": "Tablet layout and updater improvements.",
        "download_url": expected_download_url,
        "github_release_url": (
            "https://github.com/miloquinn/open-reading/releases/tag/v2.2.0"
        ),
        "website_url": "http://testserver/download",
        "sha256": hashlib.sha256(upload["payload"]).hexdigest(),
        "file_size": len(upload["payload"]),
        "published_at": expected_published_at,
        "mandatory": False,
    }
    assert body["download_url"].startswith("http://testserver/download/file/")

    missing_architecture = client.get(
        "/api/v1/releases/latest", params={"platform": "android"}
    )
    assert missing_architecture.status_code == 422
    unknown_architecture = client.get(
        "/api/v1/releases/latest",
        params={"platform": "android", "architecture": "unknown-abi"},
    )
    assert unknown_architecture.status_code == 404


def test_download_events_keep_raw_ip_for_30_days_and_admin_only(client: TestClient) -> None:
    _upload_android(client)
    release = client.get("/api/releases/latest/android").json()["items"][0]

    with client.app.state.database.connect() as connection:
        connection.execute(
            """INSERT INTO download_events (
                release_id, release_version, platform, architecture, channel, source,
                request_ip, ip_hash, user_agent, occurred_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                release["id"],
                release["version"],
                "android",
                "arm64-v8a",
                "stable",
                "old-test",
                "198.51.100.1",
                "0" * 64,
                "old-agent",
                (datetime.now(UTC) - timedelta(days=31)).isoformat(),
            ),
        )

    assert client.app.state.download_stats_service.purge_expired() == 1

    first = client.get(release["download_url"], follow_redirects=False)
    second = client.get(release["download_url"], follow_redirects=False)
    assert first.status_code == second.status_code == 302

    with client.app.state.database.connect() as connection:
        rows = connection.execute(
            "SELECT request_ip, ip_hash, user_agent FROM download_events ORDER BY id"
        ).fetchall()
    assert len(rows) == 2
    assert {row["request_ip"] for row in rows} == {"203.0.113.7"}
    assert all(row["ip_hash"] != row["request_ip"] for row in rows)

    client.cookies.clear()
    denied = client.get("/api/v1/admin/download-stats")
    assert denied.status_code == 401

    _authenticate(client)
    stats_response = client.get("/api/v1/admin/download-stats")
    assert stats_response.headers["cache-control"] == "private, no-store"
    assert stats_response.headers["pragma"] == "no-cache"
    stats = stats_response.json()
    assert stats["totals"] == {"downloads": 2, "unique_ips": 1}
    assert stats["recent"][0]["request_ip"] == "203.0.113.7"


def test_public_update_routes_are_rate_limited(client: TestClient) -> None:
    _upload_android(client)
    metadata_url = (
        "/api/v1/releases/latest?platform=android&architecture=arm64-v8a&channel=stable"
    )
    for _ in range(120):
        assert client.get(metadata_url).status_code == 200
    assert client.get(metadata_url).status_code == 429

    release = client.get("/api/releases/latest/android").json()["items"][0]
    for _ in range(30):
        assert client.get(release["download_url"], follow_redirects=False).status_code == 302
    assert client.get(release["download_url"], follow_redirects=False).status_code == 429


def _settings(tmp_path: Path) -> Settings:
    return Settings(
        base_url="http://testserver",
        database_path=tmp_path / "data" / "releases.db",
        release_root=tmp_path / "releases",
        upload_temp_root=tmp_path / "releases" / ".uploads",
        github_client_id="",
        github_client_secret="",
        github_admin_id=None,
        github_admin_login="",
        github_repository="miloquinn/open-reading",
        session_hours=12,
        oauth_state_minutes=10,
        max_upload_bytes=1024 * 1024,
        secure_cookies=False,
        download_stats_secret="test-download-stats-secret-32-bytes-minimum",
    )


def _write_import_source(
    source: Path,
    payload: bytes,
    *,
    sha256: str | None = None,
    release_notes: str = "Release mirror import",
) -> None:
    source.mkdir()
    filename = "OpenReading-Android-arm64-v8a-2.2.0.apk"
    (source / filename).write_bytes(payload)
    digest = sha256 or hashlib.sha256(payload).hexdigest()
    manifest = {
        "schema_version": 1,
        "tag": "v2.2.0",
        "version": "2.2.0",
        "build_number": "12119",
        "channel": "stable",
        "published_at": "2026-07-19T12:00:00Z",
        "release_notes": release_notes,
        "github_release_url": (
            "https://github.com/miloquinn/open-reading/releases/tag/v2.2.0"
        ),
        "mandatory": False,
        "assets": [
            {
                "filename": filename,
                "platform": "android",
                "package_type": "apk",
                "architecture": "arm64-v8a",
                "build_number": "14119",
                "size": len(payload),
                "sha256": digest,
            }
        ],
    }
    (source / "release-manifest.json").write_text(
        json.dumps(manifest), encoding="utf-8"
    )
    (source / "SHA256SUMS.txt").write_text(
        f"{digest}  ./{filename}\n", encoding="utf-8"
    )


def test_import_preserves_github_release_notes_exactly(tmp_path: Path) -> None:
    class CapturingGitHubVerifier:
        release_notes = ""

        def verify_bundle(self, *_args, **kwargs) -> None:
            self.release_notes = kwargs["release_notes"]

    settings = _settings(tmp_path)
    database = Database(settings.database_path)
    database.initialize()
    verifier = CapturingGitHubVerifier()
    service = ReleaseImportService(
        settings,
        ReleaseRepository(database),
        android_verifier=_FakeAndroidVerifier(),
        github_verifier=verifier,
    )
    source = tmp_path / "source"
    _write_import_source(
        source,
        b"PK\x03\x04mirrored-apk",
        release_notes="Release mirror import\n",
    )

    service.import_directory(
        source,
        tag="v2.2.0",
        repository="miloquinn/open-reading",
    )

    assert verifier.release_notes == "Release mirror import\n"


def test_controlled_import_is_atomic_idempotent_and_rejects_conflicts(tmp_path: Path) -> None:
    settings = _settings(tmp_path)
    database = Database(settings.database_path)
    database.initialize()
    repository = ReleaseRepository(database)
    service = _import_service(settings, repository)
    source = tmp_path / "source"
    payload = b"PK\x03\x04mirrored-apk"
    _write_import_source(source, payload)

    first = service.import_directory(
        source,
        tag="v2.2.0",
        repository="miloquinn/open-reading",
    )
    assert len(first["imported"]) == 1
    release = repository.latest("android", "arm64-v8a")[0]
    assert release.build_number == "14119"
    assert (settings.release_root / release.id / release.stored_filename).read_bytes() == payload

    second = service.import_directory(
        source,
        tag="v2.2.0",
        repository="miloquinn/open-reading",
    )
    assert second == {
        "tag": "v2.2.0",
        "version": "2.2.0",
        "imported": [],
        "reused": [release.id],
    }
    assert repository.latest("android", "arm64-v8a")[0].id == release.id

    conflicting = tmp_path / "conflicting"
    _write_import_source(conflicting, b"PK\x03\x04different-apk")
    with pytest.raises(ValueError, match="哈希或大小不同"):
        service.import_directory(
            conflicting,
            tag="v2.2.0",
            repository="miloquinn/open-reading",
        )
    assert repository.list()[1] == 1

    newer = replace(
        release,
        id="newer-release",
        version="2.3.0",
        build_number="17119",
        stored_filename="open-reading-2.3.0-android-arm64-v8a.apk",
        sha256="1" * 64,
    )
    repository.create(newer)
    assert repository.latest("android", "arm64-v8a")[0].id == newer.id
    with pytest.raises(ValueError, match="stable 版本不能回退"):
        service.import_directory(
            source,
            tag="v2.2.0",
            repository="miloquinn/open-reading",
        )
    assert repository.latest("android", "arm64-v8a")[0].id == newer.id


def test_import_rejects_checksum_mismatch_before_writing(tmp_path: Path) -> None:
    settings = _settings(tmp_path)
    database = Database(settings.database_path)
    database.initialize()
    repository = ReleaseRepository(database)
    service = _import_service(settings, repository)
    source = tmp_path / "source"
    payload = b"PK\x03\x04mirrored-apk"
    _write_import_source(source, payload, sha256="f" * 64)

    with pytest.raises(ValueError, match="sha256 校验失败"):
        service.import_directory(
            source,
            tag="v2.2.0",
            repository="miloquinn/open-reading",
        )
    assert repository.list()[1] == 0
    assert not list(settings.release_root.glob("*"))


def test_import_rejects_undeclared_files_and_apk_version_code_mismatch(tmp_path: Path) -> None:
    settings = _settings(tmp_path)
    database = Database(settings.database_path)
    database.initialize()
    repository = ReleaseRepository(database)
    service = _import_service(settings, repository)
    source = tmp_path / "source"
    payload = b"PK\x03\x04mirrored-apk"
    _write_import_source(source, payload)
    (source / "undeclared.txt").write_text("not part of the release", encoding="utf-8")

    with pytest.raises(ValueError, match="未声明文件"):
        service.import_directory(
            source,
            tag="v2.2.0",
            repository="miloquinn/open-reading",
        )

    (source / "undeclared.txt").unlink()
    service.android_verifier = _FakeAndroidVerifier("99999")
    with pytest.raises(ValueError, match="versionCode 不一致"):
        service.import_directory(
            source,
            tag="v2.2.0",
            repository="miloquinn/open-reading",
        )
    assert repository.list()[1] == 0
