from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Form, HTTPException, Request, UploadFile
from fastapi.responses import HTMLResponse, RedirectResponse

from ..models import CHANNELS
from ..services.auth import OAUTH_STATE_COOKIE, SESSION_COOKIE

router = APIRouter(prefix="/admin")


def _client(request: Request) -> tuple[str | None, str | None]:
    return (request.client.host if request.client else None, request.headers.get("user-agent"))


def _limit(request: Request, action: str, *, limit: int, window: int) -> None:
    ip, _ = _client(request)
    request.app.state.rate_limiter.require(
        f"{action}:{ip or 'unknown'}", limit=limit, window_seconds=window
    )


def _render(request: Request, template: str, context: dict, status_code: int = 200):
    templates = getattr(request.app.state, "templates", None)
    if templates is None:
        return HTMLResponse("<h1>开元阅读发行管理</h1>", status_code=status_code)
    shared = {
        "settings": request.app.state.settings,
        "site": {"name": "开元阅读", "english_name": "Open Reading"},
        "current_year": datetime.now(UTC).year,
    }
    return templates.TemplateResponse(
        request=request,
        name=template,
        context={"request": request, **shared, **context},
        status_code=status_code,
    )


@router.get("/login")
@router.get("/github")
def login(request: Request):
    _limit(request, "login", limit=10, window=60)
    if request.app.state.auth_service.session_for_request(request):
        return RedirectResponse("/admin", 303)
    try:
        url, state = request.app.state.auth_service.begin_login()
    except RuntimeError as error:
        return _render(request, "login.html", {"error": str(error), "oauth_enabled": False}, 503)
    response = RedirectResponse(url, 302)
    response.set_cookie(
        OAUTH_STATE_COOKIE,
        state,
        max_age=request.app.state.settings.oauth_state_minutes * 60,
        httponly=True,
        secure=request.app.state.settings.secure_cookies,
        samesite="lax",
        path="/admin/callback",
    )
    return response


@router.get("/callback")
async def callback(request: Request, code: str, state: str):
    _limit(request, "callback", limit=20, window=60)
    ip, agent = _client(request)
    try:
        raw_session, session = await request.app.state.auth_service.finish_login(
            code, state, request.cookies.get(OAUTH_STATE_COOKIE)
        )
    except Exception:
        request.app.state.auth_repository.audit("login_failed", request_ip=ip, user_agent=agent)
        raise
    response = RedirectResponse("/admin", 303)
    response.delete_cookie(OAUTH_STATE_COOKIE, path="/admin/callback")
    response.set_cookie(
        SESSION_COOKIE,
        raw_session,
        max_age=request.app.state.settings.session_hours * 3600,
        httponly=True,
        secure=request.app.state.settings.secure_cookies,
        samesite="lax",
        path="/",
    )
    return response


@router.post("/logout")
def logout(request: Request, csrf_token: str = Form(...)):
    _limit(request, "mutation", limit=30, window=60)
    auth = request.app.state.auth_service
    session = auth.require_session(request)
    auth.require_csrf(request, csrf_token, session)
    auth.logout(request.cookies.get(SESSION_COOKIE))
    response = RedirectResponse("/", 303)
    response.delete_cookie(SESSION_COOKIE, path="/")
    return response


@router.get("")
def dashboard(request: Request):
    session = request.app.state.auth_service.session_for_request(request)
    if session is None:
        return RedirectResponse("/admin/login", 303)
    latest = request.app.state.release_repository.latest(channel="stable")
    recent, total = request.app.state.release_repository.list(limit=20, include_unpublished=True)
    platforms = request.app.state.release_repository.platform_rows()
    latest_map = {(release.platform, release.architecture): release for release in latest}
    for platform in platforms:
        platform["latest"] = next(
            (release for release in latest if release.platform == platform["slug"]), None
        )
    storage = request.app.state.settings.release_root
    usage = __import__("shutil").disk_usage(storage)
    return _render(
        request,
        "admin/dashboard.html",
        {
            "admin": session,
            "admin_user": session,
            "csrf_token": session.csrf_token,
            "latest_releases": latest,
            "latest_by_platform": latest_map,
            "recent_releases": recent,
            "platforms": platforms,
            "storage": {"used": usage.used, "free": usage.free, "total": usage.total},
            "stats": {
                "release_count": total,
                "download_count": request.app.state.release_repository.total_download_count(),
                "storage_used_display": _human_size(usage.used),
                "storage_free_display": _human_size(usage.free),
            },
        },
    )


@router.get("/releases/new")
def new_release(request: Request):
    session = request.app.state.auth_service.session_for_request(request)
    if session is None:
        return RedirectResponse("/admin/login", 303)
    platforms = request.app.state.release_repository.platform_rows()
    return _render(
        request,
        "admin/upload.html",
        {
            "admin": session,
            "admin_user": session,
            "csrf_token": session.csrf_token,
            "platforms": platforms,
            "channels": CHANNELS,
            "form": {},
            "errors": [],
            "package_types": platforms[0]["package_types"],
            "architectures": platforms[0]["architectures"],
            "max_upload_size_display": _human_size(request.app.state.settings.max_upload_bytes),
        },
    )


@router.post("/releases/new")
async def create_release(
    request: Request,
    file: UploadFile,
    platform: str = Form(...),
    package_type: str = Form(...),
    architecture: str = Form(...),
    channel: str = Form("stable"),
    version: str = Form(...),
    build_number: str = Form(""),
    release_notes: str = Form(...),
    github_release_url: str = Form(""),
    csrf_token: str = Form(...),
    set_latest: bool = Form(True),
):
    _limit(request, "upload", limit=10, window=3600)
    auth = request.app.state.auth_service
    session = auth.require_session(request)
    auth.require_csrf(request, csrf_token, session)
    ip, agent = _client(request)
    auth.repository.audit(
        "upload_started",
        user_id=session.github_user_id,
        login=session.github_login,
        request_ip=ip,
        user_agent=agent,
        metadata={"platform": platform, "version": version},
    )
    try:
        release = await request.app.state.release_file_service.publish(
            file,
            platform=platform,
            package_type=package_type,
            architecture=architecture,
            channel=channel,
            version=version,
            build_number=build_number,
            release_notes=release_notes,
            github_release_url=github_release_url,
            make_latest=set_latest,
        )
    except ValueError as error:
        auth.repository.audit(
            "upload_failed",
            user_id=session.github_user_id,
            login=session.github_login,
            metadata={"reason": str(error)},
        )
        raise HTTPException(422, str(error)) from error
    except Exception:
        auth.repository.audit(
            "upload_failed",
            user_id=session.github_user_id,
            login=session.github_login,
            metadata={"reason": "internal_error"},
        )
        raise
    auth.repository.audit(
        "upload_succeeded",
        user_id=session.github_user_id,
        login=session.github_login,
        metadata={"release_id": release.id},
    )
    return RedirectResponse(f"/admin/releases/{release.id}", 303)


def _human_size(value: int) -> str:
    size = float(value)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if size < 1024 or unit == "TiB":
            return f"{size:.0f} {unit}" if unit == "B" else f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} TiB"


@router.get("/releases/{release_id}")
def release_detail(request: Request, release_id: str):
    session = request.app.state.auth_service.session_for_request(request)
    if session is None:
        return RedirectResponse("/admin/login", 303)
    release = request.app.state.release_repository.get(release_id, include_unpublished=True)
    if not release:
        raise HTTPException(404, "发行版本不存在")
    return _render(
        request,
        "admin/release_detail.html",
        {"admin": session, "csrf_token": session.csrf_token, "release": release},
    )


@router.get("/releases")
def release_list(request: Request):
    session = request.app.state.auth_service.session_for_request(request)
    if session is None:
        return RedirectResponse("/admin/login", 303)
    releases, total = request.app.state.release_repository.list(limit=100, include_unpublished=True)
    return _render(
        request,
        "releases.html",
        {
            "admin": session,
            "admin_user": session,
            "csrf_token": session.csrf_token,
            "releases": releases,
            "platforms": request.app.state.release_repository.platform_rows(),
            "pagination": {"page": 1, "page_size": 100, "total": total},
        },
    )


@router.post("/releases/{release_id}/latest")
def set_latest(request: Request, release_id: str, csrf_token: str = Form(...)):
    _limit(request, "mutation", limit=30, window=60)
    auth = request.app.state.auth_service
    session = auth.require_session(request)
    auth.require_csrf(request, csrf_token, session)
    try:
        release = request.app.state.release_repository.set_latest(release_id)
    except ValueError as error:
        raise HTTPException(409, str(error)) from error
    auth.repository.audit(
        "latest_changed",
        user_id=session.github_user_id,
        login=session.github_login,
        metadata={"release_id": release.id},
    )
    return RedirectResponse(f"/admin/releases/{release.id}", 303)


@router.post("/releases/{release_id}/unpublish")
def unpublish(request: Request, release_id: str, csrf_token: str = Form(...)):
    _limit(request, "mutation", limit=30, window=60)
    auth = request.app.state.auth_service
    session = auth.require_session(request)
    auth.require_csrf(request, csrf_token, session)
    release = request.app.state.release_file_service.unpublish(release_id)
    auth.repository.audit(
        "release_unpublished",
        user_id=session.github_user_id,
        login=session.github_login,
        metadata={"release_id": release.id},
    )
    return RedirectResponse(f"/admin/releases/{release.id}", 303)
