from __future__ import annotations

import json
import re
from collections.abc import Mapping
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

VERSION_PATTERN = re.compile(r"^[0-9]+(?:\.[0-9]+){1,3}(?:[-+][0-9A-Za-z.-]+)?$")
CHANNELS = ("stable", "beta", "nightly")


@dataclass(frozen=True)
class PlatformPreset:
    slug: str
    display_name: str
    package_types: tuple[str, ...]
    architectures: tuple[str, ...]
    sort_order: int

    def as_db_tuple(self) -> tuple[Any, ...]:
        return (
            self.slug,
            self.display_name,
            json.dumps(self.package_types),
            json.dumps(self.architectures),
            self.sort_order,
        )


PLATFORM_PRESETS = {
    "android": PlatformPreset(
        "android",
        "Android",
        ("apk", "aab"),
        ("arm64-v8a", "armeabi-v7a", "x86_64", "universal"),
        10,
    ),
    "ios": PlatformPreset("ios", "iOS", ("ipa",), ("arm64", "universal"), 20),
    "macos": PlatformPreset(
        "macos", "macOS", ("dmg", "pkg", "zip"), ("arm64", "x64", "universal"), 30
    ),
    "windows": PlatformPreset(
        "windows", "Windows", ("exe", "msi", "msix", "zip"), ("x64", "arm64", "x86"), 40
    ),
    "linux": PlatformPreset(
        "linux", "Linux", ("appimage", "deb", "rpm", "tar.gz"), ("x64", "arm64"), 50
    ),
}


@dataclass(frozen=True)
class Release:
    id: str
    platform: str
    package_type: str
    architecture: str
    channel: str
    version: str
    build_number: str | None
    release_notes: str
    stored_filename: str
    original_filename: str
    file_size: int
    sha256: str
    download_count: int
    github_release_url: str | None
    is_latest: bool
    is_published: bool
    published_at: str
    created_at: str
    updated_at: str
    mandatory: bool = False

    @classmethod
    def from_row(cls, row: Mapping[str, Any]) -> Release:
        values = dict(row)
        values["is_latest"] = bool(values["is_latest"])
        values["is_published"] = bool(values["is_published"])
        values["mandatory"] = bool(values.get("mandatory", 0))
        return cls(**values)

    @property
    def file_url(self) -> str:
        return f"/files/{self.id}/{self.stored_filename}"

    def public_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "platform": self.platform,
            "package_type": self.package_type,
            "architecture": self.architecture,
            "channel": self.channel,
            "version": self.version,
            "build_number": self.build_number,
            "release_notes": self.release_notes,
            "file_size": self.file_size,
            "sha256": self.sha256,
            "download_count": self.download_count,
            "github_release_url": self.github_release_url,
            "mandatory": self.mandatory,
            "is_latest": self.is_latest,
            "published_at": self.published_at,
            "download_url": f"/download/file/{self.id}",
            "file_url": self.file_url,
        }


@dataclass(frozen=True)
class AdminSession:
    github_user_id: int
    github_login: str
    avatar_url: str | None
    csrf_token: str
    expires_at: str


def utc_now() -> str:
    return datetime.now(UTC).isoformat()


def validate_release_fields(
    platform: str, package_type: str, architecture: str, channel: str, version: str
) -> None:
    preset = PLATFORM_PRESETS.get(platform)
    if preset is None:
        raise ValueError("不支持的平台")
    if package_type.lower() not in preset.package_types:
        raise ValueError("安装包类型与平台不匹配")
    if architecture not in preset.architectures:
        raise ValueError("架构与平台不匹配")
    if channel not in CHANNELS:
        raise ValueError("不支持的发布渠道")
    if not VERSION_PATTERN.fullmatch(version.strip()):
        raise ValueError("版本号格式无效")


def safe_release_filename(version: str, platform: str, architecture: str, package_type: str) -> str:
    safe_version = re.sub(r"[^0-9A-Za-z.+-]", "-", version)
    safe_arch = re.sub(r"[^0-9A-Za-z_-]", "-", architecture)
    extension = package_type.lower()
    return f"open-reading-{safe_version}-{platform}-{safe_arch}.{extension}"


def extension_for(filename: str) -> str:
    lowered = Path(filename).name.lower()
    return "tar.gz" if lowered.endswith(".tar.gz") else lowered.rsplit(".", 1)[-1]


def compare_versions(left: str, right: str) -> int:
    left_numbers, left_pre = _parse_version(left)
    right_numbers, right_pre = _parse_version(right)
    if left_numbers != right_numbers:
        return 1 if left_numbers > right_numbers else -1
    if left_pre is None and right_pre is not None:
        return 1
    if left_pre is not None and right_pre is None:
        return -1
    if left_pre is None:
        return 0
    return _compare_prerelease(left_pre, right_pre or "")


def _parse_version(value: str) -> tuple[tuple[int, ...], str | None]:
    normalized = value.strip().split("+", 1)[0]
    numeric, separator, prerelease = normalized.partition("-")
    numbers = tuple(int(item) for item in numeric.split("."))
    return (*numbers, *(0 for _ in range(4 - len(numbers)))), prerelease if separator else None


def _compare_prerelease(left: str, right: str) -> int:
    left_parts = left.split(".")
    right_parts = right.split(".")
    for index in range(max(len(left_parts), len(right_parts))):
        if index >= len(left_parts):
            return -1
        if index >= len(right_parts):
            return 1
        left_value = left_parts[index]
        right_value = right_parts[index]
        if left_value == right_value:
            continue
        left_number = int(left_value) if left_value.isdigit() else None
        right_number = int(right_value) if right_value.isdigit() else None
        if left_number is not None and right_number is not None:
            return 1 if left_number > right_number else -1
        if left_number is not None:
            return -1
        if right_number is not None:
            return 1
        return 1 if left_value > right_value else -1
    return 0
