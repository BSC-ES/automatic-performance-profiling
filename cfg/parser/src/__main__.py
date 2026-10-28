"""Allow ``python -m src`` without installing the console script."""

import sys

from .cli.main import main

if __name__ == "__main__":
    sys.exit(main())
