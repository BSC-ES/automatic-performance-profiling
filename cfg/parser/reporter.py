#!/usr/bin/env python3
"""Deprecated entry point kept for the workflow templates; use ``app-parser report``."""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from src.cli import report  # noqa: E402

if __name__ == "__main__":
    sys.exit(report.main())
