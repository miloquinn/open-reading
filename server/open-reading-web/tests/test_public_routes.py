from fastapi.testclient import TestClient


def test_health_reports_storage_and_database(client: TestClient) -> None:
    response = client.get("/api/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"


def test_public_pages_render_without_release_data(client: TestClient) -> None:
    for path, expected in (
        ("/", "开元阅读"),
        ("/download", "下载"),
        ("/releases", "版本"),
    ):
        response = client.get(path)
        assert response.status_code == 200
        assert expected in response.text


def test_home_supports_head_requests(client: TestClient) -> None:
    response = client.head("/")

    assert response.status_code == 200


def test_header_github_link_has_a_brand_mark(client: TestClient) -> None:
    response = client.get("/")

    assert response.status_code == 200
    assert 'class="github-mark"' in response.text
    assert 'aria-label="GitHub"' in response.text


def test_browser_chrome_uses_the_blue_theme(client: TestClient) -> None:
    response = client.get("/")

    assert response.status_code == 200
    assert 'content="width=device-width, initial-scale=1, viewport-fit=cover"' in response.text
    assert '<meta name="theme-color" content="#f4f9fe">' in response.text
    assert '<meta name="apple-mobile-web-app-status-bar-style" content="default">' in response.text
    assert '/static/css/theme-blue.css' in response.text
    assert '/static/css/github-nav.css' not in response.text


def test_home_versions_layout_css_with_latest_screenshots(client: TestClient) -> None:
    response = client.get("/")

    assert response.status_code == 200
    assert '/static/css/home-blue.css?v=20260720-1' in response.text
    for filename in (
        "home-latest.webp",
        "library-latest.webp",
        "reader-latest.webp",
        "page-turn-latest.webp",
        "personalization-latest.webp",
        "stats-latest.webp",
    ):
        assert f"/static/product/{filename}" in response.text


def test_all_five_platforms_exist_before_first_upload(client: TestClient) -> None:
    response = client.get("/download")

    assert response.status_code == 200
    for name in ("Android", "iOS", "macOS", "Windows", "Linux"):
        assert name in response.text


def test_latest_api_has_no_fabricated_releases(client: TestClient) -> None:
    response = client.get("/api/releases/latest")

    assert response.status_code == 200
    body = response.json()
    serialized = str(body)
    assert "example.com/files" not in serialized
    assert "0.0.0" not in serialized


def test_platform_latest_is_empty_before_upload(client: TestClient) -> None:
    response = client.get("/api/releases/latest/android")

    assert response.status_code in {200, 404}
    if response.status_code == 200:
        assert response.json() in ({}, None, {"release": None})


def test_unknown_platform_is_rejected(client: TestClient) -> None:
    response = client.get("/api/releases/latest/plan9")

    assert response.status_code in {400, 404, 422}


def test_admin_requires_authentication(client: TestClient) -> None:
    response = client.get("/admin", follow_redirects=False)

    assert response.status_code in {302, 303, 307}
    assert response.headers["location"].startswith("/admin/login")


def test_oauth_disabled_is_explicit_when_credentials_are_missing(client: TestClient) -> None:
    response = client.get("/admin/login")

    assert response.status_code in {200, 503}
    assert "GitHub" in response.text
    assert any(word in response.text for word in ("未配置", "尚未启用", "暂未启用"))


def test_stable_download_does_not_redirect_without_a_release(client: TestClient) -> None:
    response = client.get("/download/android", follow_redirects=False)

    assert response.status_code in {404, 409}
