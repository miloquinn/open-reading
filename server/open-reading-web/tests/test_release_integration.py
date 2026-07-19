import hashlib
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.services.auth import SESSION_COOKIE, token_hash


def _authenticate(client: TestClient) -> str:
    raw_session = "test-admin-session"
    csrf_token = "test-csrf-token"
    expires = (datetime.now(UTC) + timedelta(hours=1)).isoformat()
    client.app.state.auth_repository.create_session(
        token_hash(raw_session),
        12345678,
        "miloquinn",
        None,
        csrf_token,
        expires,
    )
    client.cookies.set(SESSION_COOKIE, raw_session)
    return csrf_token


def test_authenticated_upload_updates_api_and_download_shortlink(client: TestClient) -> None:
    csrf_token = _authenticate(client)
    payload = b"PK\x03\x04integration-apk"

    upload = client.post(
        "/admin/releases/new",
        data={
            "platform": "android",
            "package_type": "apk",
            "architecture": "universal",
            "channel": "stable",
            "version": "2.0.0",
            "build_number": "200",
            "release_notes": "## Changes\n\n- First hosted build",
            "github_release_url": (
                "https://github.com/miloquinn/open-reading/releases/tag/v2.0.0"
            ),
            "csrf_token": csrf_token,
            "set_latest": "true",
        },
        files={"file": ("open-reading.apk", payload, "application/vnd.android.package-archive")},
        follow_redirects=False,
    )

    assert upload.status_code == 303
    assert upload.headers["location"].startswith("/admin/releases/")

    latest = client.get("/api/releases/latest/android")
    assert latest.status_code == 200
    release = latest.json()["items"][0]
    assert release["version"] == "2.0.0"
    assert release["file_size"] == len(payload)
    assert release["sha256"] == hashlib.sha256(payload).hexdigest()

    redirect = client.get("/download/android?architecture=universal", follow_redirects=False)
    assert redirect.status_code == 302
    assert redirect.headers["location"].startswith("/files/")

    refreshed = client.get("/api/releases/latest/android").json()["items"][0]
    assert refreshed["download_count"] == 1


def test_authenticated_upload_requires_csrf(client: TestClient) -> None:
    _authenticate(client)

    response = client.post(
        "/admin/releases/new",
        data={
            "platform": "android",
            "package_type": "apk",
            "architecture": "universal",
            "channel": "stable",
            "version": "2.0.0",
            "release_notes": "Missing CSRF",
            "csrf_token": "wrong-token",
        },
        files={"file": ("open-reading.apk", b"PK\x03\x04payload")},
    )

    assert response.status_code == 403
    assert client.get("/api/releases").json()["total"] == 0
