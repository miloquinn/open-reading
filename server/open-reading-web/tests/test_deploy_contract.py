from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_release_import_wrapper_enforces_restricted_handoff() -> None:
    script = (ROOT / "deploy" / "import_release.sh").read_text(encoding="utf-8")

    for contract in (
        "SUDO_USER",
        "/tmp/open-reading-release-[0-9]+-[0-9]+",
        "stat -c '%U'",
        "stat -c '%a'",
        "chown -hR root:root",
        "chown -hR \"$SERVICE_USER:$SERVICE_USER\"",
        "trap cleanup EXIT HUP INT TERM",
        "/usr/sbin/runuser",
    ):
        assert contract in script


def test_deploy_files_do_not_contain_personal_host_defaults() -> None:
    publish = (ROOT / "deploy" / "publish.sh").read_text(encoding="utf-8")
    example = (ROOT / ".env.example").read_text(encoding="utf-8")

    assert 'DEPLOY_HOST="${DEPLOY_HOST:-' not in publish
    assert 'DEPLOY_USER="${DEPLOY_USER:-' not in publish
    assert "OPEN_READING_DOWNLOAD_STATS_SECRET=replace" not in example


def test_publish_explicitly_excludes_runtime_data_and_credentials() -> None:
    publish = (ROOT / "deploy" / "publish.sh").read_text(encoding="utf-8")

    for exclusion in (
        "--exclude '.env.*'",
        "--exclude 'data/'",
        "--exclude 'releases/'",
        "--exclude 'backups/'",
        "--exclude 'logs/'",
        "--exclude '*.db'",
        "--exclude '*.key'",
        "--exclude '*.pem'",
        "--exclude '*.jks'",
        "--exclude '*.keystore'",
    ):
        assert exclusion in publish


def test_publish_uses_the_pinned_frozen_uv_lock_for_production_dependencies() -> None:
    publish = (ROOT / "deploy" / "publish.sh").read_text(encoding="utf-8")
    workflow = (ROOT.parents[1] / ".github" / "workflows" / "release.yml").read_text(
        encoding="utf-8"
    )

    assert 'REQUIRED_UV_VERSION="0.11.8"' in publish
    assert 'UV_VERSION: "0.11.8"' in workflow
    assert "command -v uv" in publish
    assert '"$uv_bin" lock --check' in publish
    assert '"$uv_bin" sync --frozen --no-dev --python python3.12' in publish
    assert "pip install" not in publish
    assert "python3.12 -m venv" not in publish


def test_repository_ignores_backend_credentials_runtime_data_and_mirror_bundle() -> None:
    repository_ignore = (ROOT.parents[1] / ".gitignore").read_text(encoding="utf-8")
    service_ignore = (ROOT / ".gitignore").read_text(encoding="utf-8")

    for pattern in (
        "*.env",
        "*.pem",
        "*.key",
        "*.jks",
        "*.keystore",
        "*.p12",
        "*.pfx",
        "**/known_hosts",
        "**/.ssh/",
        "**/.secrets/",
        "/knowledge/",
        "*.tfstate",
        "/official-site-bundle/",
    ):
        assert pattern in repository_ignore
    for pattern in ("data/", "releases/", "backups/", "logs/", ".incoming/"):
        assert pattern in service_ignore


def test_backups_remove_raw_download_and_audit_network_details() -> None:
    backup = (ROOT / "deploy" / "backup.sh").read_text(encoding="utf-8")
    service = (ROOT / "deploy" / "open-reading-web.service").read_text(encoding="utf-8")

    assert "DELETE FROM download_events;" in backup
    assert "DELETE FROM oauth_states;" in backup
    assert "DELETE FROM admin_sessions;" in backup
    assert "UPDATE audit_events SET request_ip = NULL, user_agent = NULL;" in backup
    assert "--no-access-log" in service


def test_release_workflow_never_replaces_existing_release_assets() -> None:
    workflow = (ROOT.parents[1] / ".github" / "workflows" / "release.yml").read_text(
        encoding="utf-8"
    )
    immutability = workflow.split(
        "- name: Verify release asset immutability", maxsplit=1
    )[1].split("- name: Prevent GitHub Latest rollback", maxsplit=1)[0]

    assert "gh release upload" not in workflow
    assert "--clobber" not in workflow
    for contract in (
        '"${GITHUB_API_URL}/repos/${GH_REPO}/releases/tags/${encoded_tag}"',
        'case "$http_code" in',
        "200)",
        "404)",
        'gh release download "$RELEASE_TAG" --dir "$existing_assets_dir"',
        'for filename in "${expected_files[@]}"',
        'sha256sum "release-assets/${filename}"',
        'sha256sum "${existing_assets_dir}/${filename}"',
        'echo "RELEASE_ALREADY_EXISTS=true" >> "$GITHUB_ENV"',
        'if [[ "${RELEASE_ALREADY_EXISTS:-false}" == "true" ]]',
        'gh release edit "$RELEASE_TAG"',
        'gh release create "$RELEASE_TAG" release-assets/*',
    ):
        assert contract in workflow

    for filename in (
        "OpenReading-Android-arm64-v8a-${version}.apk",
        "OpenReading-Android-armeabi-v7a-${version}.apk",
        "OpenReading-Android-x86_64-${version}.apk",
        "OpenReading-Windows-x64-${version}.zip",
        "OpenReading-Linux-x64-${version}.tar.gz",
        "SHA256SUMS.txt",
    ):
        assert immutability.count(filename) == 1


def test_release_workflow_downloads_and_verifies_the_official_arm64_apk() -> None:
    workflow = (ROOT.parents[1] / ".github" / "workflows" / "release.yml").read_text(
        encoding="utf-8"
    )

    for contract in (
        "server/open-reading-web/scripts/verify_official_download.py",
        "--manifest official-site-bundle/release-manifest.json",
        '--response "$response_path"',
        '--output "$verified_apk_path"',
        "--idle-timeout 30",
        "--total-timeout 900",
    ):
        assert contract in workflow
