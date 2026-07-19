from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager, suppress
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from .config import Settings, get_settings
from .database import build_database
from .repositories.downloads import DownloadRepository
from .repositories.releases import AuthRepository, ReleaseRepository
from .routes import admin, api
from .services.android_package import AndroidPackageVerifier
from .services.auth import AuthService, SlidingWindowLimiter
from .services.download_stats import DownloadStatsService
from .services.release_files import ReleaseFileService


async def _download_retention_loop(app: FastAPI, *, interval_seconds: int = 3600) -> None:
    while True:
        await asyncio.sleep(interval_seconds)
        await asyncio.to_thread(app.state.download_stats_service.purge_expired)


def create_app(
    settings: Settings | None = None,
    *,
    android_package_verifier: AndroidPackageVerifier | None = None,
) -> FastAPI:
    settings = settings or get_settings()
    database = build_database(settings)
    android_package_verifier = android_package_verifier or AndroidPackageVerifier(settings)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        settings.release_root.mkdir(parents=True, exist_ok=True)
        settings.upload_temp_root.mkdir(parents=True, exist_ok=True)
        database.initialize()
        app.state.release_file_service.reconcile()
        app.state.download_repository.purge_expired()
        cleanup_task = asyncio.create_task(_download_retention_loop(app))
        try:
            yield
        finally:
            cleanup_task.cancel()
            with suppress(asyncio.CancelledError):
                await cleanup_task

    production = settings.base_url.startswith("https://")
    app = FastAPI(
        title="开元阅读",
        version="1.0.0",
        lifespan=lifespan,
        docs_url=None if production else "/docs",
        redoc_url=None if production else "/redoc",
        openapi_url=None if production else "/openapi.json",
    )
    app.state.settings = settings
    app.state.database = database
    app.state.release_repository = ReleaseRepository(database)
    app.state.download_repository = DownloadRepository(database)
    app.state.auth_repository = AuthRepository(database)
    app.state.auth_service = AuthService(settings, app.state.auth_repository)
    app.state.rate_limiter = SlidingWindowLimiter()
    app.state.download_stats_service = DownloadStatsService(
        settings, app.state.download_repository
    )
    app.state.android_package_verifier = android_package_verifier
    app.state.release_file_service = ReleaseFileService(
        settings, app.state.release_repository, android_package_verifier
    )

    templates = Path(__file__).parent / "templates"
    static = Path(__file__).parent / "static"
    if templates.exists():
        app.state.templates = Jinja2Templates(directory=str(templates))
    if static.exists():
        app.mount("/static", StaticFiles(directory=str(static)), name="static")

    try:
        from .routes import public

        app.include_router(public.router)
    except ImportError:
        pass
    app.include_router(api.router)
    app.include_router(admin.router)
    return app


app = create_app()
