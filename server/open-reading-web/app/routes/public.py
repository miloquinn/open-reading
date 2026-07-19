from __future__ import annotations

import math
from dataclasses import asdict
from datetime import datetime

from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import HTMLResponse, Response

from ..models import CHANNELS, PLATFORM_PRESETS, Release

router = APIRouter()


def _render(request: Request, template: str, context: dict, status_code: int = 200):
    templates = getattr(request.app.state, "templates", None)
    if templates is None:
        return HTMLResponse("<h1>开元阅读</h1>", status_code=status_code)
    return templates.TemplateResponse(
        request=request,
        name=template,
        context={"request": request, "current_year": datetime.now().year, **context},
        status_code=status_code,
    )


def _human_size(value: int) -> str:
    size = float(value)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if size < 1024 or unit == "TiB":
            return f"{size:.0f} {unit}" if unit == "B" else f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} TiB"


def _release_view(release: Release) -> dict:
    item = asdict(release)
    item.update(
        {
            "file_url": release.file_url,
            "download_url": f"/download/file/{release.id}",
            "file_size_display": _human_size(release.file_size),
            "published_at_display": release.published_at[:10],
            "published_date": release.published_at[:10],
            "release_notes_excerpt": release.release_notes[:180],
            "is_available": release.is_published,
        }
    )
    return item


def _platform_views(request: Request) -> list[dict]:
    latest = request.app.state.release_repository.latest(channel="stable")
    rows = request.app.state.release_repository.platform_rows()
    for row in rows:
        releases = [_release_view(item) for item in latest if item.platform == row["slug"]]
        row["latest"] = releases[0] if releases else None
        row["package_types_display"] = " · ".join(value.upper() for value in row["package_types"])
    return rows


@router.get("/")
def home(request: Request):
    return _render(
        request,
        "home.html",
        {
            "platforms": _platform_views(request),
            "github_url": "https://github.com/miloquinn/open-reading",
        },
    )


@router.head("/")
def home_head() -> Response:
    return Response(status_code=200)


@router.get("/download")
def download_center(request: Request):
    user_agent = request.headers.get("user-agent", "").lower()
    recommended = None
    for needle, platform in (
        ("android", "android"),
        ("iphone", "ios"),
        ("ipad", "ios"),
        ("windows", "windows"),
        ("macintosh", "macos"),
        ("linux", "linux"),
    ):
        if needle in user_agent:
            recommended = platform
            break
    return _render(
        request,
        "download.html",
        {
            "platforms": _platform_views(request),
            "recommended_platform": recommended,
            "github_releases_url": "https://github.com/miloquinn/open-reading/releases",
        },
    )


@router.get("/releases")
def releases(
    request: Request,
    platform: str | None = None,
    channel: str | None = None,
    page: int = Query(1, ge=1),
):
    if platform and platform not in PLATFORM_PRESETS:
        raise HTTPException(422, "无效平台")
    if channel and channel not in CHANNELS:
        raise HTTPException(422, "无效渠道")
    page_size = 20
    items, total = request.app.state.release_repository.list(
        platform=platform,
        channel=channel,
        limit=page_size,
        offset=(page - 1) * page_size,
    )
    pages = max(1, math.ceil(total / page_size))

    def page_url(target: int) -> str:
        values = [f"page={target}"]
        if platform:
            values.append(f"platform={platform}")
        if channel:
            values.append(f"channel={channel}")
        return "/releases?" + "&".join(values)

    return _render(
        request,
        "releases.html",
        {
            "releases": [_release_view(item) for item in items],
            "platforms": request.app.state.release_repository.platform_rows(),
            "selected_platform": platform,
            "selected_channel": channel,
            "pagination": {
                "page": page,
                "pages": pages,
                "prev_url": page_url(page - 1) if page > 1 else None,
                "next_url": page_url(page + 1) if page < pages else None,
            },
        },
    )


@router.get("/releases/{release_id}")
def release_detail(request: Request, release_id: str):
    release = request.app.state.release_repository.get(release_id)
    if release is None:
        raise HTTPException(404, "发行版本不存在或已下架")
    return _render(request, "release_detail.html", {"release": _release_view(release)})
