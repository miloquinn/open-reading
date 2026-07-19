import hashlib
from io import BytesIO
from pathlib import Path

import pytest
from fastapi import UploadFile

from app.config import Settings
from app.database import Database
from app.repositories.releases import ReleaseRepository
from app.services.release_files import ReleaseFileService


class _FakeAndroidVerifier:
    def verify(self, _path: Path, *, version_name: str, version_code: str) -> None:
        if not version_name or not version_code:
            raise ValueError("missing APK version metadata")


def _settings(tmp_path: Path, *, max_upload_bytes: int = 1024) -> Settings:
    return Settings(
        base_url="http://testserver",
        database_path=tmp_path / "data" / "releases.db",
        release_root=tmp_path / "releases",
        upload_temp_root=tmp_path / "releases" / ".uploads",
        github_client_id="",
        github_client_secret="",
        github_admin_id=12345678,
        github_admin_login="miloquinn",
        github_repository="miloquinn/open-reading",
        session_hours=12,
        oauth_state_minutes=10,
        max_upload_bytes=max_upload_bytes,
        secure_cookies=False,
    )


def _service(settings: Settings) -> tuple[ReleaseFileService, ReleaseRepository]:
    database = Database(settings.database_path)
    database.initialize()
    repository = ReleaseRepository(database)
    return ReleaseFileService(settings, repository, _FakeAndroidVerifier()), repository


@pytest.mark.asyncio
async def test_publish_streams_hashes_and_atomically_records_file(tmp_path: Path) -> None:
    settings = _settings(tmp_path)
    service, repository = _service(settings)
    payload = b"PK\x03\x04valid-apk-payload"

    release = await service.publish(
        UploadFile(filename="reader.apk", file=BytesIO(payload)),
        platform="android",
        package_type="apk",
        architecture="universal",
        channel="stable",
        version="1.0.0",
        build_number="100",
        release_notes="First public build",
        github_release_url="https://github.com/miloquinn/open-reading/releases/tag/v1.0.0",
    )

    stored = settings.release_root / release.id / release.stored_filename
    assert stored.read_bytes() == payload
    assert release.file_size == len(payload)
    assert release.sha256 == hashlib.sha256(payload).hexdigest()
    assert repository.latest("android", "universal")[0].id == release.id
    assert not list(settings.upload_temp_root.glob("*.part"))


@pytest.mark.asyncio
async def test_invalid_signature_leaves_no_file_or_metadata(tmp_path: Path) -> None:
    settings = _settings(tmp_path)
    service, repository = _service(settings)

    with pytest.raises(ValueError, match="文件头"):
        await service.publish(
            UploadFile(filename="reader.apk", file=BytesIO(b"not-an-apk")),
            platform="android",
            package_type="apk",
            architecture="universal",
            channel="stable",
            version="1.0.0",
            build_number=None,
            release_notes="Invalid upload",
            github_release_url=None,
        )

    assert repository.list()[1] == 0
    assert not list(settings.release_root.rglob("*.apk"))
    assert not list(settings.upload_temp_root.glob("*.part"))


@pytest.mark.asyncio
async def test_oversized_upload_leaves_no_file_or_metadata(tmp_path: Path) -> None:
    settings = _settings(tmp_path, max_upload_bytes=8)
    service, repository = _service(settings)

    with pytest.raises(ValueError, match="最大大小"):
        await service.publish(
            UploadFile(filename="reader.apk", file=BytesIO(b"PK\x03\x04too-large")),
            platform="android",
            package_type="apk",
            architecture="universal",
            channel="stable",
            version="1.0.0",
            build_number=None,
            release_notes="Oversized upload",
            github_release_url=None,
        )

    assert repository.list()[1] == 0
    assert not list(settings.release_root.rglob("*.apk"))
    assert not list(settings.upload_temp_root.glob("*.part"))


@pytest.mark.asyncio
async def test_manual_apk_upload_requires_version_metadata_and_verifier(tmp_path: Path) -> None:
    settings = _settings(tmp_path)
    service, repository = _service(settings)

    with pytest.raises(ValueError, match="version metadata"):
        await service.publish(
            UploadFile(filename="reader.apk", file=BytesIO(b"PK\x03\x04payload")),
            platform="android",
            package_type="apk",
            architecture="universal",
            channel="stable",
            version="1.0.0",
            build_number=None,
            release_notes="Missing build number",
            github_release_url=None,
        )

    assert repository.list()[1] == 0


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "url",
    [
        "javascript:alert(1)",
        "https://example.com/miloquinn/open-reading/releases/tag/v1",
        "http://github.com/miloquinn/open-reading/releases/tag/v1",
        "https://github.com/miloquinn/open-reading/releases-foo/tag/v1",
    ],
)
async def test_github_release_url_must_use_project_https_releases(
    tmp_path: Path, url: str
) -> None:
    settings = _settings(tmp_path)
    service, repository = _service(settings)

    with pytest.raises(ValueError, match="GitHub 镜像"):
        await service.publish(
            UploadFile(filename="reader.apk", file=BytesIO(b"PK\x03\x04payload")),
            platform="android",
            package_type="apk",
            architecture="universal",
            channel="stable",
            version="1.0.0",
            build_number=None,
            release_notes="Invalid mirror",
            github_release_url=url,
        )

    assert repository.list()[1] == 0


@pytest.mark.asyncio
async def test_unpublish_removes_file_from_public_root(tmp_path: Path) -> None:
    settings = _settings(tmp_path)
    service, repository = _service(settings)
    release = await service.publish(
        UploadFile(filename="reader.apk", file=BytesIO(b"PK\x03\x04payload")),
        platform="android",
        package_type="apk",
        architecture="universal",
        channel="stable",
        version="1.0.0",
        build_number="100",
        release_notes="First build",
        github_release_url=None,
    )

    service.unpublish(release.id)

    assert not (settings.release_root / release.id).exists()
    assert (settings.database_path.parent / "quarantine" / release.id).exists()
    assert repository.get(release.id) is None


def test_reconcile_quarantines_orphan_release_directory(tmp_path: Path) -> None:
    settings = _settings(tmp_path)
    service, _ = _service(settings)
    orphan = settings.release_root / "orphan-id"
    orphan.mkdir(parents=True)
    (orphan / "unknown.apk").write_bytes(b"PK\x03\x04payload")

    issues = service.reconcile()

    assert "orphan:orphan-id" in issues
    assert not orphan.exists()
    assert (settings.database_path.parent / "quarantine" / "orphan-id").exists()


@pytest.mark.asyncio
async def test_reconcile_unpublishes_missing_file_and_quarantines_directory(
    tmp_path: Path,
) -> None:
    settings = _settings(tmp_path)
    service, repository = _service(settings)
    release = await service.publish(
        UploadFile(filename="reader.apk", file=BytesIO(b"PK\x03\x04payload")),
        platform="android",
        package_type="apk",
        architecture="universal",
        channel="stable",
        version="1.0.0",
        build_number="100",
        release_notes="First build",
        github_release_url=None,
    )
    stored = settings.release_root / release.id / release.stored_filename
    stored.unlink()

    issues = service.reconcile()

    assert f"missing:{release.id}" in issues
    assert repository.get(release.id) is None
    assert not (settings.release_root / release.id).exists()
    assert (settings.database_path.parent / "quarantine" / release.id).exists()
