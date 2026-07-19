from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from app.config import Settings
from app.services.android_package import AndroidPackageVerifier


def _settings(tmp_path: Path, certificate: str) -> Settings:
    return Settings(
        base_url="http://testserver",
        database_path=tmp_path / "releases.db",
        release_root=tmp_path / "releases",
        upload_temp_root=tmp_path / ".uploads",
        github_client_id="",
        github_client_secret="",
        github_admin_id=None,
        github_admin_login="",
        github_repository="miloquinn/open-reading",
        session_hours=12,
        oauth_state_minutes=10,
        max_upload_bytes=1024,
        secure_cookies=False,
        download_stats_secret="test-download-stats-secret-32-bytes-minimum",
        android_cert_sha256=certificate,
    )


@pytest.mark.parametrize("signer_label", ["Signer #1", "V2 Signer"])
def test_android_verifier_checks_package_version_and_certificate(
    tmp_path: Path, signer_label: str
) -> None:
    certificate = "ab" * 32
    calls: list[list[str]] = []

    def runner(command: list[str], **_kwargs) -> subprocess.CompletedProcess[str]:
        calls.append(command)
        if command[0] == "/tools/aapt":
            output = (
                "package: name='com.niki.xxread' versionCode='14119' "
                "versionName='2.2.0' platformBuildVersionName=''"
            )
        else:
            output = f"{signer_label}: certificate SHA-256 digest: {certificate}"
        return subprocess.CompletedProcess(command, 0, output, "")

    verifier = AndroidPackageVerifier(
        _settings(tmp_path, certificate),
        which=lambda name: f"/tools/{name}",
        runner=runner,
    )
    verifier.verify(tmp_path / "release.apk", version_name="2.2.0", version_code="14119")

    assert calls == [
        ["/tools/aapt", "dump", "badging", str(tmp_path / "release.apk")],
        [
            "/tools/apksigner",
            "verify",
            "--print-certs",
            str(tmp_path / "release.apk"),
        ],
    ]


@pytest.mark.parametrize(
    ("certificate", "which", "message"),
    [
        ("", lambda name: f"/tools/{name}", "ANDROID_CERT_SHA256"),
        ("ab" * 32, lambda _name: None, "aapt 和 apksigner"),
    ],
)
def test_android_verifier_rejects_missing_identity_or_tools(
    tmp_path: Path, certificate: str, which, message: str, monkeypatch
) -> None:
    monkeypatch.delenv("ANDROID_HOME", raising=False)
    monkeypatch.delenv("ANDROID_SDK_ROOT", raising=False)
    verifier = AndroidPackageVerifier(_settings(tmp_path, certificate), which=which)

    with pytest.raises(ValueError, match=message):
        verifier.verify(
            tmp_path / "release.apk", version_name="2.2.0", version_code="14119"
        )


def test_android_verifier_rejects_wrong_package_or_signature(tmp_path: Path) -> None:
    certificate = "ab" * 32

    def wrong_package(command: list[str], **_kwargs) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(
            command,
            0,
            "package: name='example.invalid' versionCode='14119' versionName='2.2.0'",
            "",
        )

    verifier = AndroidPackageVerifier(
        _settings(tmp_path, certificate),
        which=lambda name: f"/tools/{name}",
        runner=wrong_package,
    )
    with pytest.raises(ValueError, match="packageName"):
        verifier.verify(
            tmp_path / "release.apk", version_name="2.2.0", version_code="14119"
        )


def test_android_verifier_rejects_any_unexpected_additional_signer(tmp_path: Path) -> None:
    certificate = "ab" * 32

    def runner(command: list[str], **_kwargs) -> subprocess.CompletedProcess[str]:
        if command[0] == "/tools/aapt":
            output = (
                "package: name='com.niki.xxread' versionCode='14119' "
                "versionName='2.2.0'"
            )
        else:
            output = (
                f"Signer #1 certificate SHA-256 digest: {certificate}\n"
                f"Signer #2 certificate SHA-256 digest: {'cd' * 32}\n"
                f"Source Stamp Signer certificate SHA-256 digest: {'ef' * 32}"
            )
        return subprocess.CompletedProcess(command, 0, output, "")

    verifier = AndroidPackageVerifier(
        _settings(tmp_path, certificate),
        which=lambda name: f"/tools/{name}",
        runner=runner,
    )
    with pytest.raises(ValueError, match="正式发布身份"):
        verifier.verify(
            tmp_path / "release.apk", version_name="2.2.0", version_code="14119"
        )
