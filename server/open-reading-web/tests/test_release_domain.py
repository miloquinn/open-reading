from dataclasses import replace
from datetime import UTC, datetime
from pathlib import Path

import pytest

from app.database import Database
from app.models import (
    Release,
    compare_versions,
    extension_for,
    safe_release_filename,
    validate_release_fields,
)
from app.repositories.releases import ReleaseRepository


def _release(release_id: str, version: str, *, latest: bool = True) -> Release:
    now = datetime.now(UTC).isoformat()
    return Release(
        id=release_id,
        platform="android",
        package_type="apk",
        architecture="universal",
        channel="stable",
        version=version,
        build_number=None,
        release_notes=f"Release {version}",
        stored_filename=f"open-reading-{version}-android-universal.apk",
        original_filename="app-release.apk",
        file_size=4,
        sha256="0" * 64,
        download_count=0,
        github_release_url=None,
        is_latest=latest,
        is_published=True,
        published_at=now,
        created_at=now,
        updated_at=now,
    )


@pytest.mark.parametrize(
    ("platform", "package_type", "architecture"),
    [
        ("android", "apk", "universal"),
        ("ios", "ipa", "arm64"),
        ("macos", "dmg", "universal"),
        ("windows", "msix", "x64"),
        ("linux", "appimage", "arm64"),
    ],
)
def test_platform_combinations_are_preconfigured(
    platform: str, package_type: str, architecture: str
) -> None:
    validate_release_fields(platform, package_type, architecture, "stable", "1.2.3")


@pytest.mark.parametrize(
    ("platform", "package_type", "architecture", "version"),
    [
        ("android", "exe", "universal", "1.0.0"),
        ("ios", "ipa", "x64", "1.0.0"),
        ("linux", "deb", "x64", "latest"),
    ],
)
def test_invalid_release_metadata_is_rejected(
    platform: str, package_type: str, architecture: str, version: str
) -> None:
    with pytest.raises(ValueError):
        validate_release_fields(platform, package_type, architecture, "stable", version)


def test_filename_is_server_controlled_and_tar_gz_is_detected() -> None:
    assert (
        safe_release_filename("1.2.3-rc.1", "linux", "x64", "tar.gz")
        == "open-reading-1.2.3-rc.1-linux-x64.tar.gz"
    )
    assert extension_for("../../Open Reading.tar.gz") == "tar.gz"


def test_latest_switch_is_unique_and_download_count_is_atomic(tmp_path: Path) -> None:
    database = Database(tmp_path / "releases.db")
    database.initialize()
    repository = ReleaseRepository(database)

    first = repository.create(_release("first", "1.0.0"))
    repository.create(_release("second", "1.1.0"))

    assert first.id == "first"
    assert [item.id for item in repository.latest("android", "universal")] == ["second"]
    assert repository.get("first").is_latest is False  # type: ignore[union-attr]

    with pytest.raises(ValueError, match="stable 版本不能回退"):
        repository.set_latest("first")
    assert [item.id for item in repository.latest("android", "universal")] == ["second"]
    counted = repository.increment_download("second")
    assert counted is not None
    assert counted.download_count == 1


def test_stable_latest_floor_survives_unpublish_but_beta_can_roll_back(
    tmp_path: Path,
) -> None:
    database = Database(tmp_path / "releases.db")
    database.initialize()
    repository = ReleaseRepository(database)
    repository.create(_release("stable-old", "2.2.0"))
    repository.create(_release("stable-new", "2.3.0"))
    repository.unpublish("stable-new")

    with pytest.raises(ValueError, match="stable 版本不能回退"):
        repository.set_latest("stable-old")

    beta_old = replace(_release("beta-old", "2.2.0"), channel="beta")
    beta_new = replace(_release("beta-new", "2.3.0"), channel="beta")
    repository.create(beta_old)
    repository.create(beta_new)
    repository.set_latest("beta-old")
    assert repository.latest("android", "universal", "beta")[0].id == "beta-old"


def test_unpublished_release_is_not_downloadable(tmp_path: Path) -> None:
    database = Database(tmp_path / "releases.db")
    database.initialize()
    repository = ReleaseRepository(database)
    repository.create(_release("release", "1.0.0"))

    repository.unpublish("release")

    assert repository.get("release") is None
    assert repository.increment_download("release") is None


def test_version_comparison_is_monotonic_for_stable_and_prerelease_versions() -> None:
    assert compare_versions("2.3.0", "2.2.0") > 0
    assert compare_versions("2.2.0", "2.2.0") == 0
    assert compare_versions("2.2.0", "2.2.0-rc.1") > 0
    assert compare_versions("2.2.0-rc.2", "2.2.0-rc.1") > 0


def test_total_download_count_sums_every_release_not_only_recent_rows(tmp_path: Path) -> None:
    database = Database(tmp_path / "releases.db")
    database.initialize()
    repository = ReleaseRepository(database)
    expected = 0
    for index in range(25):
        count = index + 1
        expected += count
        repository.create(
            replace(
                _release(f"release-{index}", f"1.0.{index}", latest=False),
                download_count=count,
            ),
            make_latest=False,
        )

    assert repository.total_download_count() == expected
