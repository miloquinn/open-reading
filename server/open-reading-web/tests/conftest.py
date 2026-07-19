from collections.abc import Iterator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient


class FakeAndroidPackageVerifier:
    def verify(self, _path: Path, *, version_name: str, version_code: str) -> None:
        if not version_name or not version_code:
            raise ValueError("missing APK version metadata")


@pytest.fixture
def app_env(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> Path:
    data_dir = tmp_path / "data"
    releases_dir = tmp_path / "releases"
    data_dir.mkdir()
    releases_dir.mkdir()

    values = {
        "OPEN_READING_BASE_URL": "http://testserver",
        "OPEN_READING_DATA_ROOT": str(data_dir),
        "OPEN_READING_RELEASE_ROOT": str(releases_dir),
        "OPEN_READING_DATABASE": str(data_dir / "releases.db"),
        "OPEN_READING_UPLOAD_TEMP": str(releases_dir / ".uploads"),
        "GITHUB_CLIENT_ID": "",
        "GITHUB_CLIENT_SECRET": "",
        "GITHUB_ADMIN_ID": "12345678",
        "GITHUB_ADMIN_LOGIN": "miloquinn",
        "OPEN_READING_MAX_UPLOAD_BYTES": "1048576",
        "OPEN_READING_SECURE_COOKIES": "false",
        "OPEN_READING_DOWNLOAD_STATS_SECRET": "test-download-stats-secret-32-bytes-minimum",
    }
    for key, value in values.items():
        monkeypatch.setenv(key, value)
    return tmp_path


@pytest.fixture
def client(app_env: Path) -> Iterator[TestClient]:
    from app.config import get_settings
    from app.main import create_app

    get_settings.cache_clear()
    with TestClient(
        create_app(android_package_verifier=FakeAndroidPackageVerifier()),
        client=("203.0.113.7", 50000),
    ) as test_client:
        yield test_client
    get_settings.cache_clear()
