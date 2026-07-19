#!/usr/bin/env python3
"""Refresh the five platform presets without changing release rows."""

from app.config import get_settings
from app.database import build_database


def main() -> None:
    database = build_database(get_settings())
    database.initialize()
    print("Platform presets are up to date.")


if __name__ == "__main__":
    main()
