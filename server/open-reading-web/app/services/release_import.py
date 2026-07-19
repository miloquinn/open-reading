from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import uuid
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from ..config import Settings
from ..models import (
    Release,
    compare_versions,
    extension_for,
    safe_release_filename,
    utc_now,
    validate_release_fields,
)
from ..repositories.releases import ReleaseRepository
from .android_package import AndroidPackageVerifier
from .github_release import GitHubAssetSpec, GitHubReleaseVerifier
from .release_files import SIGNATURES

SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
TAG_PATTERN = re.compile(r"^v([0-9]+(?:\.[0-9]+){1,3}(?:[-+][0-9A-Za-z.-]+)?)$")
REPOSITORY_PATTERN = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")


@dataclass(frozen=True)
class ImportAsset:
    filename: str
    platform: str
    package_type: str
    architecture: str
    build_number: str
    size: int
    sha256: str


@dataclass(frozen=True)
class ImportManifest:
    tag: str
    version: str
    build_number: str
    channel: str
    published_at: str
    release_notes: str
    github_release_url: str
    mandatory: bool
    assets: tuple[ImportAsset, ...]


class ReleaseImportService:
    def __init__(
        self,
        settings: Settings,
        repository: ReleaseRepository,
        *,
        android_verifier: AndroidPackageVerifier | None = None,
        github_verifier: GitHubReleaseVerifier | None = None,
    ):
        self.settings = settings
        self.repository = repository
        self.android_verifier = android_verifier or AndroidPackageVerifier(settings)
        self.github_verifier = github_verifier or GitHubReleaseVerifier()

    def import_directory(
        self,
        source: Path,
        *,
        tag: str,
        repository: str,
        manifest_name: str = "release-manifest.json",
    ) -> dict[str, Any]:
        source = source.resolve(strict=True)
        if not source.is_dir():
            raise ValueError("source 必须是目录")
        if Path(manifest_name).name != manifest_name:
            raise ValueError("manifest 必须是 source 下的普通文件名")
        manifest_path = self._safe_source_file(source, manifest_name)
        sums_path = self._safe_source_file(source, "SHA256SUMS.txt")
        payload = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest = self._parse_manifest(payload, tag=tag, repository=repository)
        sums = self._parse_sums(sums_path)
        asset_names = {asset.filename for asset in manifest.assets}
        if set(sums) != asset_names:
            raise ValueError("SHA256SUMS.txt 必须与 manifest assets 完全一致")
        expected_names = {manifest_name, "SHA256SUMS.txt", *asset_names}
        actual_names = {item.name for item in source.iterdir()}
        if actual_names != expected_names or any(
            not item.is_file() or item.is_symlink() for item in source.iterdir()
        ):
            raise ValueError("source 包含未声明文件、目录或符号链接")
        self.github_verifier.verify_bundle(
            source,
            tag=tag,
            version=manifest.version,
            repository=repository,
            github_release_url=manifest.github_release_url,
            published_at=manifest.published_at,
            release_notes=manifest.release_notes,
            channel=manifest.channel,
            asset_specs={
                asset.filename: GitHubAssetSpec(
                    size=asset.size,
                    sha256=asset.sha256,
                    platform=asset.platform,
                    package_type=asset.package_type,
                    architecture=asset.architecture,
                )
                for asset in manifest.assets
            },
        )

        if manifest.channel == "stable":
            for asset in manifest.assets:
                current = self.repository.latest(
                    asset.platform, asset.architecture, manifest.channel
                )
                if current and compare_versions(manifest.version, current[0].version) < 0:
                    raise ValueError(
                        f"stable 版本不能回退: current={current[0].version} "
                        f"requested={manifest.version}"
                    )

        validated: list[tuple[ImportAsset, Path]] = []
        for asset in manifest.assets:
            path = self._safe_source_file(source, asset.filename)
            if sums.get(asset.filename) != asset.sha256:
                raise ValueError(f"SHA256SUMS.txt 与 manifest 不一致: {asset.filename}")
            self._validate_asset_file(path, asset, version=manifest.version)
            validated.append((asset, path))

        imported: list[Release] = []
        reused: list[Release] = []
        pending: list[tuple[Release, Path]] = []
        now = utc_now()
        for asset, path in validated:
            existing = self.repository.find_identity(
                platform=asset.platform,
                architecture=asset.architecture,
                channel=manifest.channel,
                version=manifest.version,
                package_type=asset.package_type,
            )
            if existing is not None:
                stored = self.settings.release_root / existing.id / existing.stored_filename
                if (
                    existing.sha256 != asset.sha256
                    or existing.file_size != asset.size
                    or existing.build_number != asset.build_number
                    or not stored.is_file()
                ):
                    raise ValueError(
                        "同版本、平台、架构、渠道和构建号已经存在，但文件哈希或大小不同"
                    )
                reused.append(existing)
                continue

            release_id = str(uuid.uuid4())
            pending.append(
                (
                    Release(
                        id=release_id,
                        platform=asset.platform,
                        package_type=asset.package_type,
                        architecture=asset.architecture,
                        channel=manifest.channel,
                        version=manifest.version,
                        build_number=asset.build_number,
                        release_notes=manifest.release_notes,
                        stored_filename=safe_release_filename(
                            manifest.version,
                            asset.platform,
                            asset.architecture,
                            asset.package_type,
                        ),
                        original_filename=asset.filename,
                        file_size=asset.size,
                        sha256=asset.sha256,
                        download_count=0,
                        github_release_url=manifest.github_release_url,
                        is_latest=True,
                        is_published=True,
                        published_at=manifest.published_at,
                        created_at=now,
                        updated_at=now,
                        mandatory=manifest.mandatory,
                    ),
                    path,
                )
            )

        self.settings.release_root.mkdir(parents=True, exist_ok=True)
        self.settings.upload_temp_root.mkdir(parents=True, exist_ok=True)
        created_directories: list[Path] = []
        try:
            for release, source_path in pending:
                temp_path = self.settings.upload_temp_root / f"{release.id}.import.part"
                self._copy_atomic_source(source_path, temp_path)
                final_directory = self.settings.release_root / release.id
                final_directory.mkdir(parents=True, exist_ok=False)
                created_directories.append(final_directory)
                os.replace(temp_path, final_directory / release.stored_filename)
            imported = self.repository.create_many(
                [release for release, _ in pending],
                activate_existing=[release.id for release in reused],
            )
        except Exception:
            for release, _ in pending:
                (self.settings.upload_temp_root / f"{release.id}.import.part").unlink(
                    missing_ok=True
                )
            for directory in created_directories:
                shutil.rmtree(directory, ignore_errors=True)
            raise

        return {
            "tag": manifest.tag,
            "version": manifest.version,
            "imported": [release.id for release in imported],
            "reused": [release.id for release in reused],
        }

    def _parse_manifest(
        self, payload: Any, *, tag: str, repository: str
    ) -> ImportManifest:
        if not isinstance(payload, dict) or payload.get("schema_version") != 1:
            raise ValueError("仅支持 release manifest schema_version=1")
        tag_match = TAG_PATTERN.fullmatch(tag)
        if tag_match is None or payload.get("tag") != tag:
            raise ValueError("tag 与 manifest 不一致")
        version = str(payload.get("version") or "").strip()
        if version != tag_match.group(1):
            raise ValueError("version 必须与 tag 一致")
        configured_repository = self.settings.github_repository.strip()
        if (
            not REPOSITORY_PATTERN.fullmatch(repository)
            or repository != configured_repository
        ):
            raise ValueError("repository 与服务配置不一致")
        build_number = str(payload.get("build_number") or "").strip()
        if not build_number:
            raise ValueError("manifest build_number 不能为空")
        channel = str(payload.get("channel") or "stable").strip()
        published_at = str(payload.get("published_at") or "").strip()
        self._validate_timestamp(published_at)
        expected_url = f"https://github.com/{repository}/releases/tag/{tag}"
        github_release_url = str(payload.get("github_release_url") or "").strip()
        if github_release_url != expected_url:
            raise ValueError("github_release_url 与 tag/repository 不一致")
        raw_assets = payload.get("assets")
        if not isinstance(raw_assets, list) or not raw_assets:
            raise ValueError("manifest 至少需要一个 asset")

        assets: list[ImportAsset] = []
        seen: set[str] = set()
        seen_slots: set[tuple[str, str]] = set()
        for raw in raw_assets:
            if not isinstance(raw, dict):
                raise ValueError("asset 必须是对象")
            filename = str(raw.get("filename") or "").strip()
            if not filename or Path(filename).name != filename or filename in seen:
                raise ValueError("asset filename 必须唯一且不能包含路径")
            seen.add(filename)
            package_type = str(raw.get("package_type") or "").strip().lower()
            if extension_for(filename) != package_type:
                raise ValueError(f"asset 扩展名与 package_type 不一致: {filename}")
            platform = str(raw.get("platform") or "").strip()
            architecture = str(raw.get("architecture") or "").strip()
            asset_build_number = str(raw.get("build_number") or "").strip()
            if not asset_build_number:
                raise ValueError(f"asset build_number 不能为空: {filename}")
            if package_type != "apk" and asset_build_number != build_number:
                raise ValueError(
                    f"非 APK asset build_number 必须与 manifest 一致: {filename}"
                )
            validate_release_fields(
                platform, package_type, architecture, channel, version
            )
            slot = (platform, architecture)
            if slot in seen_slots:
                raise ValueError("同一 manifest 不能重复声明平台/架构发行槽位")
            seen_slots.add(slot)
            size = raw.get("size")
            sha256 = str(raw.get("sha256") or "").strip().lower()
            if not isinstance(size, int) or size <= 0 or size > self.settings.max_upload_bytes:
                raise ValueError(f"asset size 无效: {filename}")
            if not SHA256_PATTERN.fullmatch(sha256):
                raise ValueError(f"asset sha256 无效: {filename}")
            assets.append(
                ImportAsset(
                    filename=filename,
                    platform=platform,
                    package_type=package_type,
                    architecture=architecture,
                    build_number=asset_build_number,
                    size=size,
                    sha256=sha256,
                )
            )
        mandatory = payload.get("mandatory", False)
        if not isinstance(mandatory, bool):
            raise ValueError("mandatory 必须是布尔值")
        release_notes = payload.get("release_notes")
        if release_notes is None:
            release_notes = ""
        if not isinstance(release_notes, str):
            raise ValueError("release_notes 必须是字符串")
        return ImportManifest(
            tag=tag,
            version=version,
            build_number=build_number,
            channel=channel,
            published_at=published_at,
            release_notes=release_notes,
            github_release_url=github_release_url,
            mandatory=mandatory,
            assets=tuple(assets),
        )

    @staticmethod
    def _parse_sums(path: Path) -> dict[str, str]:
        result: dict[str, str] = {}
        for line in path.read_text(encoding="utf-8").splitlines():
            stripped = line.strip()
            if not stripped:
                continue
            match = re.fullmatch(r"([0-9A-Fa-f]{64})\s+\*?(.+)", stripped)
            if match is None:
                raise ValueError("SHA256SUMS.txt 格式无效")
            filename = match.group(2).strip().removeprefix("./")
            if Path(filename).name != filename or filename in result:
                raise ValueError("SHA256SUMS.txt 包含无效或重复文件名")
            result[filename] = match.group(1).lower()
        return result

    @staticmethod
    def _safe_source_file(source: Path, filename: str) -> Path:
        candidate = source / filename
        if candidate.is_symlink():
            raise ValueError(f"不允许符号链接: {filename}")
        resolved = candidate.resolve(strict=True)
        if resolved.parent != source or not resolved.is_file():
            raise ValueError(f"文件不在 source 根目录: {filename}")
        return resolved

    @staticmethod
    def _validate_timestamp(value: str) -> None:
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError as error:
            raise ValueError("published_at 必须是 ISO-8601 时间") from error
        if parsed.tzinfo is None:
            raise ValueError("published_at 必须包含时区")

    def _validate_asset_file(
        self, path: Path, asset: ImportAsset, *, version: str
    ) -> None:
        stat = path.stat()
        if stat.st_size != asset.size:
            raise ValueError(f"asset size 校验失败: {asset.filename}")
        digest = hashlib.sha256()
        header = b""
        tail = b""
        with path.open("rb") as source:
            while chunk := source.read(1024 * 1024):
                if len(header) < 16:
                    header += chunk[: 16 - len(header)]
                tail = (tail + chunk)[-512:]
                digest.update(chunk)
        if digest.hexdigest() != asset.sha256:
            raise ValueError(f"asset sha256 校验失败: {asset.filename}")
        signatures = SIGNATURES.get(asset.package_type)
        if signatures and not any(header.startswith(signature) for signature in signatures):
            raise ValueError(f"asset 文件头校验失败: {asset.filename}")
        if asset.package_type == "dmg" and not tail.startswith(b"koly"):
            raise ValueError(f"DMG trailer 校验失败: {asset.filename}")
        if asset.package_type == "apk":
            self.android_verifier.verify(
                path,
                version_name=version,
                version_code=asset.build_number,
            )

    @staticmethod
    def _copy_atomic_source(source: Path, destination: Path) -> None:
        destination.parent.mkdir(parents=True, exist_ok=True)
        with source.open("rb") as reader, destination.open("xb") as writer:
            shutil.copyfileobj(reader, writer, length=1024 * 1024)
            writer.flush()
            os.fsync(writer.fileno())
