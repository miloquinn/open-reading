from fastapi.testclient import TestClient


def test_mutation_cannot_be_used_without_a_session(client: TestClient) -> None:
    response = client.post(
        "/admin/releases/new",
        data={
            "platform": "android",
            "package_type": "apk",
            "architecture": "universal",
            "channel": "stable",
            "version": "1.0.0",
            "release_notes": "Initial release",
            "csrf_token": "not-authenticated",
        },
        files={"file": ("open-reading.apk", b"PK\x03\x04payload")},
        follow_redirects=False,
    )

    assert response.status_code in {302, 303, 307, 401, 403}


def test_oauth_callback_rejects_missing_or_unmatched_state(client: TestClient) -> None:
    response = client.get(
        "/admin/callback?code=not-a-real-code&state=untrusted", follow_redirects=False
    )

    assert response.status_code in {302, 303, 307, 400, 401, 403}


def test_sensitive_paths_are_not_public(client: TestClient) -> None:
    for path in ("/.env", "/data/releases.db", "/releases.db"):
        response = client.get(path)
        assert response.status_code in {403, 404}
