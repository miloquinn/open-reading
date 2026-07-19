from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import quote

import httpx

SHA256_LINE = re.compile(r"([0-9A-Fa-f]{64})\s+\*?(.+)")
MAX_METADATA_BYTES = 4 * 1024 * 1024
OFFICIAL_ASSET_NAMES = {
    ("android", "apk", "arm64-v8a"): "OpenReading-Android-arm64-v8a-{version}.apk",
    ("android", "apk", "armeabi-v7a"): "OpenReading-Android-armeabi-v7a-{version}.apk",
    ("android", "apk", "x86_64"): "OpenReading-Android-x86_64-{version}.apk",
    ("windows", "zip", "x64"): "OpenReading-Windows-x64-{version}.zip",
    ("linux", "tar.gz", "x64"): "OpenReading-Linux-x64-{version}.tar.gz",
}


@dataclass(frozen=True)
class GitHubAssetSpec:
    size: int
    sha256: str
    platform: str
    package_type: str
    architecture: str


class GitHubReleaseVerifier:
    def __init__(self, *, client: httpx.Client | None = None):
        self._client = client

    def verify_bundle(
        self,
        source: Path,
        *,
        tag: str,
        version: str,
        repository: str,
        github_release_url: str,
        published_at: str,
        release_notes: str,
        channel: str,
        asset_specs: dict[str, GitHubAssetSpec],
    ) -> None:
        if self._client is not None:
            self._verify(
                self._client,
                source,
                tag=tag,
                version=version,
                repository=repository,
                github_release_url=github_release_url,
                published_at=published_at,
                release_notes=release_notes,
                channel=channel,
                asset_specs=asset_specs,
            )
            return
        with httpx.Client(
            timeout=30,
            follow_redirects=True,
            headers={
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
                "User-Agent": "OpenReading-Official-Release-Importer",
            },
        ) as client:
            self._verify(
                client,
                source,
                tag=tag,
                version=version,
                repository=repository,
                github_release_url=github_release_url,
                published_at=published_at,
                release_notes=release_notes,
                channel=channel,
                asset_specs=asset_specs,
            )

    def _verify(
        self,
        client: httpx.Client,
        source: Path,
        *,
        tag: str,
        version: str,
        repository: str,
        github_release_url: str,
        published_at: str,
        release_notes: str,
        channel: str,
        asset_specs: dict[str, GitHubAssetSpec],
    ) -> None:
        self._verify_asset_mapping(version, asset_specs)
        try:
            response = client.get(
                f"https://api.github.com/repos/{repository}/releases/tags/{tag}"
            )
            response.raise_for_status()
            release = response.json()
        except (httpx.HTTPError, ValueError) as error:
            raise ValueError("无法从 GitHub API 核验正式 Release") from error
        if not isinstance(release, dict) or release.get("tag_name") != tag:
            raise ValueError("GitHub Release tag 与导入请求不一致")
        if release.get("html_url") != github_release_url:
            raise ValueError("manifest GitHub Release URL 与 GitHub API 不一致")
        if release.get("published_at") != published_at:
            raise ValueError("manifest published_at 与 GitHub API 不一致")
        official_notes = release.get("body")
        if official_notes is None:
            official_notes = ""
        if not isinstance(official_notes, str) or official_notes != release_notes:
            raise ValueError("manifest release_notes 与 GitHub API 不一致")
        if release.get("draft") is True:
            raise ValueError("不能导入 GitHub draft Release")
        if channel == "stable" and release.get("prerelease") is True:
            raise ValueError("stable 渠道不能导入 GitHub prerelease")

        raw_assets = release.get("assets")
        if not isinstance(raw_assets, list):
            raise ValueError("GitHub Release assets 响应无效")
        official_assets: dict[str, dict[str, Any]] = {}
        for raw in raw_assets:
            if not isinstance(raw, dict):
                raise ValueError("GitHub Release asset 响应无效")
            name = str(raw.get("name") or "")
            if not name or name in official_assets:
                raise ValueError("GitHub Release asset 名称为空或重复")
            official_assets[name] = raw

        expected_names = {"SHA256SUMS.txt", *asset_specs}
        if set(official_assets) != expected_names:
            raise ValueError("manifest 资产集合与 GitHub Release assets 不完全一致")
        for name, official in official_assets.items():
            if official.get("state") != "uploaded":
                raise ValueError(f"GitHub Release asset 尚未上传完成: {name}")
            local_path = source / name
            official_size = official.get("size")
            if not isinstance(official_size, int) or official_size != local_path.stat().st_size:
                raise ValueError(f"本地文件大小与 GitHub Release 不一致: {name}")
            expected_download_url = (
                f"https://github.com/{repository}/releases/download/{quote(tag)}/{quote(name)}"
            )
            if official.get("browser_download_url") != expected_download_url:
                raise ValueError(f"GitHub Release asset 下载地址无效: {name}")
            digest = official.get("digest")
            if name in asset_specs and digest is not None:
                expected_digest = f"sha256:{asset_specs[name].sha256}"
                if digest != expected_digest:
                    raise ValueError(f"GitHub Release asset digest 与 manifest 不一致: {name}")

        official_sums = self._download_metadata(
            client, official_assets["SHA256SUMS.txt"], "SHA256SUMS.txt"
        )
        local_sums = (source / "SHA256SUMS.txt").read_bytes()
        if official_sums != local_sums:
            raise ValueError("本地 SHA256SUMS.txt 与 GitHub 官方资产不一致")
        parsed_sums = self._parse_sums(official_sums.decode("utf-8"))
        if parsed_sums != {name: spec.sha256 for name, spec in asset_specs.items()}:
            raise ValueError("GitHub 官方 SHA256SUMS 与 manifest assets 不一致")

    @staticmethod
    def _verify_asset_mapping(
        version: str, asset_specs: dict[str, GitHubAssetSpec]
    ) -> None:
        slots = {
            (spec.platform, spec.package_type, spec.architecture): filename
            for filename, spec in asset_specs.items()
        }
        if len(slots) != len(asset_specs) or set(slots) != set(OFFICIAL_ASSET_NAMES):
            raise ValueError("manifest 必须映射正式发行的五个安装包槽位")
        for slot, filename_template in OFFICIAL_ASSET_NAMES.items():
            expected_filename = filename_template.format(version=version)
            if slots[slot] != expected_filename:
                raise ValueError(
                    f"manifest asset filename 不符合正式命名规则: {slots[slot]}"
                )

    @staticmethod
    def _download_metadata(
        client: httpx.Client, asset: dict[str, Any], name: str
    ) -> bytes:
        url = str(asset.get("browser_download_url") or "")
        if not url:
            raise ValueError(f"GitHub asset 缺少下载地址: {name}")
        try:
            response = client.get(url)
            response.raise_for_status()
        except httpx.HTTPError as error:
            raise ValueError(f"无法下载 GitHub 官方元数据资产: {name}") from error
        if len(response.content) > MAX_METADATA_BYTES:
            raise ValueError(f"GitHub 元数据资产过大: {name}")
        return response.content

    @staticmethod
    def _parse_sums(value: str) -> dict[str, str]:
        result: dict[str, str] = {}
        for line in value.splitlines():
            stripped = line.strip()
            if not stripped:
                continue
            match = SHA256_LINE.fullmatch(stripped)
            if match is None:
                raise ValueError("GitHub SHA256SUMS.txt 格式无效")
            filename = match.group(2).strip().removeprefix("./")
            if Path(filename).name != filename or filename in result:
                raise ValueError("GitHub SHA256SUMS.txt 文件名无效或重复")
            result[filename] = match.group(1).lower()
        return result
