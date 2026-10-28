#!/usr/bin/env python3
"""Deprecated entry point kept for the workflow templates; use ``app-parser compare``."""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from src.cli import compare  # noqa: E402

if __name__ == "__main__":
    sys.exit(compare.main())
