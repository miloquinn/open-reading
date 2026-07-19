from __future__ import annotations

import os
import re
import shutil
import subprocess
from collections.abc import Callable
from pathlib import Path

from ..config import Settings

PACKAGE_PATTERN = re.compile(
    r"package:\s+name='([^']+)'\s+versionCode='([^']+)'\s+versionName='([^']+)'"
)
CERT_PATTERN = re.compile(
    r"^(?:Signer #\d+|V\d+ Signer):?\s+certificate SHA-256 digest:\s*"
    r"([0-9A-Fa-f: ]+)$",
    re.IGNORECASE | re.MULTILINE,
)


class AndroidPackageVerifier:
    def __init__(
        self,
        settings: Settings,
        *,
        which: Callable[[str], str | None] = shutil.which,
        runner: Callable[..., subprocess.CompletedProcess[str]] = subprocess.run,
    ):
        self.settings = settings
        self._which = which
        self._runner = runner

    def verify(self, path: Path, *, version_name: str, version_code: str) -> None:
        expected_cert = self._normalized_certificate(self.settings.android_cert_sha256)
        if not expected_cert:
            raise ValueError("OPEN_READING_ANDROID_CERT_SHA256 尚未配置")
        if not version_name.strip() or not version_code.strip():
            raise ValueError("APK versionName 和 versionCode 均不能为空")

        aapt = self._find_android_tool("aapt")
        apksigner = self._find_android_tool("apksigner")
        if not aapt or not apksigner:
            raise ValueError("服务器必须安装 aapt 和 apksigner 才能接收 APK")

        badging = self._run([aapt, "dump", "badging", str(path)], "aapt 校验失败")
        package_match = PACKAGE_PATTERN.search(badging)
        if package_match is None:
            raise ValueError("aapt 无法读取 APK 包信息")
        package_name, actual_code, actual_name = package_match.groups()
        if package_name != "com.niki.xxread":
            raise ValueError("APK packageName 必须是 com.niki.xxread")
        if actual_name != version_name.strip():
            raise ValueError(
                f"APK versionName 不一致: expected={version_name.strip()} actual={actual_name}"
            )
        if actual_code != version_code.strip():
            raise ValueError(
                f"APK versionCode 不一致: expected={version_code.strip()} actual={actual_code}"
            )

        signer_output = self._run(
            [apksigner, "verify", "--print-certs", str(path)], "apksigner 校验失败"
        )
        signer_certificates = {
            normalized
            for match in CERT_PATTERN.finditer(signer_output)
            if (normalized := self._normalized_certificate(match.group(1)))
        }
        if not signer_certificates:
            raise ValueError("apksigner 未返回签名证书 SHA-256")
        if signer_certificates != {expected_cert}:
            raise ValueError("APK 签名证书 SHA-256 与正式发布身份不一致")

    def _find_android_tool(self, name: str) -> str | None:
        direct = self._which(name)
        if direct:
            return direct
        executable_names = (name, f"{name}.bat", f"{name}.exe")
        for variable in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
            root = os.getenv(variable, "").strip()
            if not root:
                continue
            build_tools = Path(root) / "build-tools"
            if not build_tools.is_dir():
                continue
            for version_dir in sorted(build_tools.iterdir(), reverse=True):
                for executable_name in executable_names:
                    candidate = version_dir / executable_name
                    if candidate.is_file():
                        return str(candidate)
        return None

    def _run(self, command: list[str], error_message: str) -> str:
        try:
            result = self._runner(
                command,
                check=True,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=60,
            )
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            raise ValueError(error_message) from error
        return f"{result.stdout}\n{result.stderr}"

    @staticmethod
    def _normalized_certificate(value: str) -> str:
        normalized = re.sub(r"[^0-9A-Fa-f]", "", value).lower()
        return normalized if len(normalized) == 64 else ""
