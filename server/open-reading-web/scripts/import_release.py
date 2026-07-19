#!/usr/bin/env python3
"""Import one verified GitHub Release mirror from a local staging directory."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from app.config import get_settings
from app.database import build_database
from app.repositories.releases import ReleaseRepository
from app.services.release_files import ReleaseFileService
from app.services.release_import import ReleaseImportService


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--manifest", default="release-manifest.json")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    settings = get_settings()
    database = build_database(settings)
    database.initialize()
    repository = ReleaseRepository(database)
    ReleaseFileService(settings, repository).reconcile()
    result = ReleaseImportService(settings, repository).import_directory(
        args.source,
        tag=args.tag,
        repository=args.repository,
        manifest_name=args.manifest,
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
