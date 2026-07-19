from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query, Request, Response
from fastapi.responses import RedirectResponse

from ..models import CHANNELS, PLATFORM_PRESETS

router = APIRouter()


def _repo(request: Request):
    return request.app.state.release_repository


def _client_key(request: Request) -> str:
    return request.client.host if request.client else "unknown"


def _limit_metadata(request: Request) -> None:
    request.app.state.rate_limiter.require(
        f"release-metadata:{_client_key(request)}", limit=120, window_seconds=60
    )


def _limit_download(request: Request) -> None:
    request.app.state.rate_limiter.require(
        f"release-download:{_client_key(request)}", limit=30, window_seconds=60 * 60
    )


def _v1_release(request: Request, release) -> dict:
    base_url = request.app.state.settings.base_url.rstrip("/")
    return {
        "schema_version": 1,
        "version": release.version,
        "build_number": release.build_number,
        "platform": release.platform,
        "architecture": release.architecture,
        "package_type": release.package_type,
        "channel": release.channel,
        "release_notes": release.release_notes,
        "download_url": f"{base_url}/download/file/{release.id}",
        "github_release_url": release.github_release_url,
        "website_url": f"{base_url}/download",
        "sha256": release.sha256,
        "file_size": release.file_size,
        "published_at": release.published_at,
        "mandatory": release.mandatory,
    }


@router.get("/api/health")
def health(request: Request) -> dict:
    try:
        with request.app.state.database.connect() as connection:
            connection.execute("SELECT 1").fetchone()
        storage_ok, issues = request.app.state.release_file_service.storage_status()
        if not storage_ok:
            raise HTTPException(503, detail={"status": "degraded", "issues": issues})
        return {"status": "ok", "database": "ok", "storage": "ok"}
    except HTTPException:
        raise
    except Exception as error:
        raise HTTPException(503, "服务暂不可用") from error


@router.get("/api/platforms")
def platforms(request: Request) -> dict:
    return {"items": _repo(request).platform_rows()}


@router.get("/api/releases/latest")
def all_latest(request: Request, channel: str = "stable") -> dict:
    if channel not in CHANNELS:
        raise HTTPException(422, "无效渠道")
    items = _repo(request).latest(channel=channel)
    return {"items": [item.public_dict() for item in items]}


@router.get("/api/releases/latest/{platform}")
def platform_latest(
    request: Request, platform: str, architecture: str | None = None, channel: str = "stable"
) -> dict:
    if platform not in PLATFORM_PRESETS or channel not in CHANNELS:
        raise HTTPException(404, "未找到对应平台")
    items = _repo(request).latest(platform, architecture, channel)
    if not items:
        raise HTTPException(404, "该平台尚无可用安装包")
    return {"items": [item.public_dict() for item in items]}


@router.get("/api/v1/releases/latest")
def v1_latest(
    request: Request,
    response: Response,
    platform: str,
    architecture: str | None = None,
    abi: str | None = None,
    channel: str = "stable",
) -> dict:
    _limit_metadata(request)
    response.headers["Cache-Control"] = "no-store"
    if platform not in PLATFORM_PRESETS or channel not in CHANNELS:
        raise HTTPException(404, "未找到对应平台或渠道")
    if architecture and abi and architecture != abi:
        raise HTTPException(422, "architecture 与 abi 不一致")
    selected_architecture = architecture or abi
    if platform == "android" and not selected_architecture:
        raise HTTPException(422, "Android 更新检查必须提供 architecture 或 abi")
    if (
        selected_architecture
        and selected_architecture not in PLATFORM_PRESETS[platform].architectures
    ):
        raise HTTPException(404, "未找到对应架构")
    items = _repo(request).latest(platform, selected_architecture, channel)
    if not items:
        raise HTTPException(404, "该平台尚无可用安装包")
    release = next((item for item in items if item.architecture == "universal"), items[0])
    return _v1_release(request, release)


@router.get("/api/releases")
def releases(
    request: Request,
    platform: str | None = None,
    channel: str | None = None,
    architecture: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
) -> dict:
    items, total = _repo(request).list(
        platform=platform,
        channel=channel,
        architecture=architecture,
        limit=page_size,
        offset=(page - 1) * page_size,
    )
    return {
        "items": [item.public_dict() for item in items],
        "page": page,
        "page_size": page_size,
        "total": total,
    }


@router.get("/download/{platform}")
def download_latest(
    request: Request, platform: str, architecture: str | None = None, channel: str = "stable"
):
    _limit_download(request)
    if platform not in PLATFORM_PRESETS:
        raise HTTPException(404, "未找到对应平台")
    items = _repo(request).latest(platform, architecture, channel)
    if not items:
        raise HTTPException(404, "该平台尚无可用安装包")
    release = request.app.state.download_stats_service.record(
        request, items[0].id, source="platform-shortlink"
    )
    if release is None:
        raise HTTPException(404, "发行版本不存在或已下架")
    return RedirectResponse(
        release.file_url, status_code=302, headers={"Cache-Control": "no-store"}
    )


@router.get("/download/file/{release_id}")
def download_release(request: Request, release_id: str):
    _limit_download(request)
    release = request.app.state.download_stats_service.record(
        request, release_id, source="release-shortlink"
    )
    if release is None:
        raise HTTPException(404, "发行版本不存在或已下架")
    return RedirectResponse(
        release.file_url, status_code=302, headers={"Cache-Control": "no-store"}
    )


@router.get("/api/v1/releases/{version}/assets/{release_id}")
def v1_download_release(request: Request, version: str, release_id: str):
    _limit_download(request)
    candidate = _repo(request).get(release_id)
    if candidate is None or candidate.version != version:
        raise HTTPException(404, "发行版本不存在或已下架")
    release = request.app.state.download_stats_service.record(
        request, release_id, source="v1-release-asset"
    )
    if release is None:
        raise HTTPException(404, "发行版本不存在或已下架")
    return RedirectResponse(
        release.file_url, status_code=302, headers={"Cache-Control": "no-store"}
    )


@router.get("/api/v1/admin/download-stats")
def v1_download_stats(
    request: Request,
    response: Response,
    days: int = Query(30, ge=1, le=30),
) -> dict:
    request.app.state.auth_service.require_session(request)
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["Pragma"] = "no-cache"
    return {
        "schema_version": 1,
        **request.app.state.download_stats_service.summary(days=days),
    }
