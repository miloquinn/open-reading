from __future__ import annotations

import hashlib
import os
import shutil
import uuid
from pathlib import Path
from urllib.parse import urlparse

from fastapi import UploadFile

from ..config import Settings
from ..models import Release, extension_for, safe_release_filename, utc_now, validate_release_fields
from ..repositories.releases import ReleaseRepository
from .android_package import AndroidPackageVerifier

SIGNATURES: dict[str, tuple[bytes, ...]] = {
    "apk": (b"PK\x03\x04",),
    "aab": (b"PK\x03\x04",),
    "ipa": (b"PK\x03\x04",),
    "zip": (b"PK\x03\x04",),
    "msix": (b"PK\x03\x04",),
    "pkg": (b"xar!",),
    "exe": (b"MZ",),
    "msi": (bytes.fromhex("d0cf11e0a1b11ae1"),),
    "appimage": (b"\x7fELF",),
    "deb": (b"!<arch>\n",),
    "rpm": (bytes.fromhex("edabeedb"),),
    "tar.gz": (b"\x1f\x8b",),
}

ALLOWED_CONTENT_TYPES: dict[str, tuple[str, ...]] = {
    "apk": ("application/vnd.android.package-archive", "application/zip"),
    "aab": ("application/zip",),
    "ipa": ("application/zip",),
    "dmg": ("application/x-apple-diskimage",),
    "pkg": ("application/octet-stream", "application/x-xar"),
    "zip": ("application/zip",),
    "exe": ("application/vnd.microsoft.portable-executable", "application/x-msdownload"),
    "msi": ("application/x-msi", "application/x-ole-storage"),
    "msix": ("application/vnd.ms-appx", "application/zip"),
    "appimage": ("application/vnd.appimage", "application/x-executable"),
    "deb": ("application/vnd.debian.binary-package",),
    "rpm": ("application/x-rpm",),
    "tar.gz": ("application/gzip", "application/x-gzip"),
}


class ReleaseFileService:
    def __init__(
        self,
        settings: Settings,
        repository: ReleaseRepository,
        android_verifier: AndroidPackageVerifier | None = None,
    ):
        self.settings = settings
        self.repository = repository
        self.android_verifier = android_verifier or AndroidPackageVerifier(settings)

    async def publish(
        self,
        upload: UploadFile,
        *,
        platform: str,
        package_type: str,
        architecture: str,
        channel: str,
        version: str,
        build_number: str | None,
        release_notes: str,
        github_release_url: str | None,
        make_latest: bool = True,
    ) -> Release:
        package_type = package_type.lower()
        validate_release_fields(platform, package_type, architecture, channel, version)
        github_release_url = self._validate_github_release_url(github_release_url)
        original_filename = Path(upload.filename or "").name
        if not original_filename or extension_for(original_filename) != package_type:
            raise ValueError("文件扩展名与安装包类型不匹配")
        content_type = (upload.content_type or "application/octet-stream").split(";", 1)[0].strip()
        allowed_types = ALLOWED_CONTENT_TYPES.get(package_type, ())
        if content_type != "application/octet-stream" and content_type not in allowed_types:
            raise ValueError("安装包 MIME 类型与所选类型不匹配")
        self.settings.upload_temp_root.mkdir(parents=True, exist_ok=True)
        release_id = str(uuid.uuid4())
        temp_path = self.settings.upload_temp_root / f"{release_id}.part"
        final_directory: Path | None = None
        digest, size, header, tail = hashlib.sha256(), 0, b"", b""
        try:
            with temp_path.open("xb") as target:
                while chunk := await upload.read(1024 * 1024):
                    size += len(chunk)
                    if size > self.settings.max_upload_bytes:
                        raise ValueError("安装包超过允许的最大大小")
                    if len(header) < 16:
                        header += chunk[: 16 - len(header)]
                    tail = (tail + chunk)[-512:]
                    digest.update(chunk)
                    target.write(chunk)
                target.flush()
                os.fsync(target.fileno())
            if size == 0:
                raise ValueError("安装包不能为空")
            signatures = SIGNATURES.get(package_type)
            if signatures and not any(header.startswith(signature) for signature in signatures):
                raise ValueError("安装包文件头与所选类型不匹配")
            if package_type == "dmg" and not tail.startswith(b"koly"):
                raise ValueError("DMG 文件缺少有效的 trailer")
            if package_type == "apk":
                self.android_verifier.verify(
                    temp_path,
                    version_name=version.strip(),
                    version_code=(build_number or "").strip(),
                )
            final_name = safe_release_filename(version, platform, architecture, package_type)
            final_directory = self.settings.release_root / release_id
            final_directory.mkdir(parents=True, exist_ok=False)
            final_path = final_directory / final_name
            os.replace(temp_path, final_path)
            now = utc_now()
            release = Release(
                id=release_id,
                platform=platform,
                package_type=package_type,
                architecture=architecture,
                channel=channel,
                version=version.strip(),
                build_number=build_number or None,
                release_notes=release_notes.strip(),
                stored_filename=final_name,
                original_filename=original_filename,
                file_size=size,
                sha256=digest.hexdigest(),
                download_count=0,
                github_release_url=github_release_url or None,
                is_latest=make_latest,
                is_published=True,
                published_at=now,
                created_at=now,
                updated_at=now,
            )
            try:
                return self.repository.create(release, make_latest=make_latest)
            except Exception:
                shutil.rmtree(final_directory, ignore_errors=True)
                raise
        except Exception:
            if final_directory is not None:
                shutil.rmtree(final_directory, ignore_errors=True)
            raise
        finally:
            await upload.close()
            temp_path.unlink(missing_ok=True)

    def unpublish(self, release_id: str) -> Release:
        release = self.repository.get(release_id, include_unpublished=True)
        if release is None:
            raise LookupError("发行版本不存在")
        source = self.settings.release_root / release.id
        quarantine = self.settings.database_path.parent / "quarantine"
        quarantine.mkdir(parents=True, exist_ok=True)
        destination = quarantine / release.id
        moved = False
        if source.exists():
            if destination.exists():
                shutil.rmtree(destination)
            os.replace(source, destination)
            moved = True
        try:
            return self.repository.unpublish(release_id)
        except Exception:
            if moved and destination.exists():
                os.replace(destination, source)
            raise

    def reconcile(self) -> list[str]:
        issues: list[str] = []
        self.settings.release_root.mkdir(parents=True, exist_ok=True)
        quarantine = self.settings.database_path.parent / "quarantine"
        quarantine.mkdir(parents=True, exist_ok=True)
        releases = self.repository.all(include_unpublished=True)
        known = {release.id: release for release in releases}
        for release in releases:
            directory = self.settings.release_root / release.id
            file_path = directory / release.stored_filename
            if release.is_published and not file_path.is_file():
                self.repository.unpublish(release.id)
                if directory.exists():
                    target = quarantine / release.id
                    if target.exists():
                        shutil.rmtree(target)
                    os.replace(directory, target)
                issues.append(f"missing:{release.id}")
            elif not release.is_published and directory.exists():
                target = quarantine / release.id
                if target.exists():
                    shutil.rmtree(target)
                os.replace(directory, target)
                issues.append(f"quarantined:{release.id}")
        for directory in self.settings.release_root.iterdir():
            if not directory.is_dir() or directory == self.settings.upload_temp_root:
                continue
            if directory.name not in known:
                target = quarantine / directory.name
                if target.exists():
                    shutil.rmtree(target)
                os.replace(directory, target)
                issues.append(f"orphan:{directory.name}")
        return issues

    def storage_status(self) -> tuple[bool, list[str]]:
        issues: list[str] = []
        try:
            self.settings.upload_temp_root.mkdir(parents=True, exist_ok=True)
            probe = self.settings.upload_temp_root / f".health-{uuid.uuid4().hex}"
            probe.write_bytes(b"ok")
            probe.unlink()
        except OSError:
            issues.append("storage-not-writable")
        for release in self.repository.all(include_unpublished=False):
            file_path = self.settings.release_root / release.id / release.stored_filename
            if not file_path.is_file():
                issues.append(f"missing:{release.id}")
        return not issues, issues

    @staticmethod
    def _validate_github_release_url(value: str | None) -> str | None:
        candidate = (value or "").strip()
        if not candidate:
            return None
        parsed = urlparse(candidate)
        allowed_path = "/miloquinn/open-reading/releases"
        if (
            parsed.scheme != "https"
            or parsed.netloc != "github.com"
            or not (parsed.path == allowed_path or parsed.path.startswith(f"{allowed_path}/"))
        ):
            raise ValueError("GitHub 镜像必须是本项目的 HTTPS Releases 地址")
        return candidate
