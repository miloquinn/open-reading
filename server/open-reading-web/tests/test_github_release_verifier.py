from __future__ import annotations

import hashlib
import json
from pathlib import Path
from urllib.parse import quote

import httpx
import pytest

from app.services.github_release import GitHubAssetSpec, GitHubReleaseVerifier

REPOSITORY = "miloquinn/open-reading"
TAG = "v2.2.0"
VERSION = "2.2.0"
RELEASE_URL = f"https://github.com/{REPOSITORY}/releases/tag/{TAG}"
PUBLISHED_AT = "2026-07-19T12:00:00Z"
RELEASE_NOTES = "Official release notes"
ASSET_LAYOUT = (
    ("OpenReading-Android-arm64-v8a-2.2.0.apk", "android", "apk", "arm64-v8a"),
    (
        "OpenReading-Android-armeabi-v7a-2.2.0.apk",
        "android",
        "apk",
        "armeabi-v7a",
    ),
    ("OpenReading-Android-x86_64-2.2.0.apk", "android", "apk", "x86_64"),
    ("OpenReading-Windows-x64-2.2.0.zip", "windows", "zip", "x64"),
    ("OpenReading-Linux-x64-2.2.0.tar.gz", "linux", "tar.gz", "x64"),
)


def _bundle(tmp_path: Path) -> tuple[Path, dict[str, GitHubAssetSpec]]:
    source = tmp_path / "bundle"
    source.mkdir(parents=True)
    specs: dict[str, GitHubAssetSpec] = {}
    manifest_assets = []
    sums = []
    for filename, platform, package_type, architecture in ASSET_LAYOUT:
        payload = f"official-{filename}".encode()
        digest = hashlib.sha256(payload).hexdigest()
        (source / filename).write_bytes(payload)
        specs[filename] = GitHubAssetSpec(
            size=len(payload),
            sha256=digest,
            platform=platform,
            package_type=package_type,
            architecture=architecture,
        )
        manifest_assets.append(
            {"filename": filename, "size": len(payload), "sha256": digest}
        )
        sums.append(f"{digest}  ./{filename}")
    (source / "SHA256SUMS.txt").write_text("\n".join(sums) + "\n", encoding="utf-8")
    (source / "release-manifest.json").write_text(
        json.dumps(
            {
                "schema_version": 1,
                "tag": TAG,
                "version": VERSION,
                "published_at": PUBLISHED_AT,
                "release_notes": RELEASE_NOTES,
                "github_release_url": RELEASE_URL,
                "assets": manifest_assets,
            },
            separators=(",", ":"),
        ),
        encoding="utf-8",
    )
    return source, specs


def _mock_client(
    source: Path,
    specs: dict[str, GitHubAssetSpec],
    *,
    fail_api: bool = False,
    release_overrides: dict | None = None,
) -> httpx.Client:
    sums = (source / "SHA256SUMS.txt").read_bytes()
    assets = [
        {
            "name": "SHA256SUMS.txt",
            "state": "uploaded",
            "size": len(sums),
            "browser_download_url": (
                f"https://github.com/{REPOSITORY}/releases/download/{TAG}/SHA256SUMS.txt"
            ),
        }
    ]
    assets.extend(
        {
            "name": name,
            "state": "uploaded",
            "size": spec.size,
            "digest": f"sha256:{spec.sha256}",
            "browser_download_url": (
                f"https://github.com/{REPOSITORY}/releases/download/"
                f"{quote(TAG)}/{quote(name)}"
            ),
        }
        for name, spec in specs.items()
    )
    release = {
        "tag_name": TAG,
        "html_url": RELEASE_URL,
        "published_at": PUBLISHED_AT,
        "body": RELEASE_NOTES,
        "draft": False,
        "prerelease": False,
        "assets": assets,
        **(release_overrides or {}),
    }

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "api.github.com":
            if fail_api:
                raise httpx.ConnectError("offline", request=request)
            return httpx.Response(200, json=release)
        if request.url.path.endswith("/SHA256SUMS.txt"):
            return httpx.Response(200, content=sums)
        raise AssertionError(f"unexpected metadata request: {request.url}")

    return httpx.Client(transport=httpx.MockTransport(handler), follow_redirects=True)


def _verify(
    source: Path,
    specs: dict[str, GitHubAssetSpec],
    client: httpx.Client,
    **overrides,
) -> None:
    arguments = {
        "tag": TAG,
        "version": VERSION,
        "repository": REPOSITORY,
        "github_release_url": RELEASE_URL,
        "published_at": PUBLISHED_AT,
        "release_notes": RELEASE_NOTES,
        "channel": "stable",
        "asset_specs": specs,
        **overrides,
    }
    GitHubReleaseVerifier(client=client).verify_bundle(source, **arguments)


def test_github_release_verifier_matches_five_official_assets_and_sums(
    tmp_path: Path,
) -> None:
    source, specs = _bundle(tmp_path)
    with _mock_client(source, specs) as client:
        _verify(source, specs, client)


@pytest.mark.parametrize(
    ("release_overrides", "verify_overrides", "message"),
    [
        ({"body": "changed"}, {}, "release_notes"),
        ({"published_at": "2026-07-19T12:00:01Z"}, {}, "published_at"),
        ({"html_url": "https://example.invalid"}, {}, "Release URL"),
    ],
)
def test_github_release_verifier_rejects_manifest_metadata_mismatch(
    tmp_path: Path,
    release_overrides: dict,
    verify_overrides: dict,
    message: str,
) -> None:
    source, specs = _bundle(tmp_path)
    with (
        _mock_client(source, specs, release_overrides=release_overrides) as client,
        pytest.raises(ValueError, match=message),
    ):
        _verify(source, specs, client, **verify_overrides)


def test_github_release_verifier_rejects_sums_tampering_and_network_failure(
    tmp_path: Path,
) -> None:
    source, specs = _bundle(tmp_path)
    with _mock_client(source, specs) as client:
        (source / "SHA256SUMS.txt").write_text("tampered\n", encoding="utf-8")
        with pytest.raises(ValueError, match="SHA256SUMS"):
            _verify(source, specs, client)

    source, specs = _bundle(tmp_path / "offline")
    with (
        _mock_client(source, specs, fail_api=True) as client,
        pytest.raises(ValueError, match="GitHub API"),
    ):
        _verify(source, specs, client)


def test_github_release_verifier_rejects_non_official_asset_mapping(
    tmp_path: Path,
) -> None:
    source, specs = _bundle(tmp_path)
    removed = specs.pop("OpenReading-Linux-x64-2.2.0.tar.gz")
    specs["OpenReading-Linux-arm64-2.2.0.tar.gz"] = GitHubAssetSpec(
        size=removed.size,
        sha256=removed.sha256,
        platform="linux",
        package_type="tar.gz",
        architecture="arm64",
    )
    with (
        _mock_client(source, specs) as client,
        pytest.raises(ValueError, match="五个安装包槽位"),
    ):
        _verify(source, specs, client)
