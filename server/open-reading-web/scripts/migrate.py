#!/usr/bin/env python3
"""Initialize or migrate the release database to the current schema."""

from app.config import get_settings
from app.database import build_database


def main() -> None:
    settings = get_settings()
    build_database(settings).initialize()
    print(f"Database is ready: {settings.database_path}")


if __name__ == "__main__":
    main()

