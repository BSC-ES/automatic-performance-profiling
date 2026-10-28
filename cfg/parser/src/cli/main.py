"""``app-parser``: one command with a ``collect``, ``report`` and ``compare`` verb."""

import sys

from .. import __version__
from . import collect, compare, report

COMMANDS = {
    "collect": collect.main,
    "report": report.main,
    "compare": compare.main,
}

USAGE = """usage: app-parser <command> [options]

commands:
  collect   parse the raw outputs of one test into <output>.json
  report    produce the CSVs, plots and summaries of one <test>.json
  compare   compare several <test>.json of the same member

Run 'app-parser <command> --help' for the options of a command."""


def main(argv=None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if not argv or argv[0] in ("-h", "--help"):
        print(f"app-parser {__version__}\n\n{USAGE}")
        return 0
    if argv[0] in ("-V", "--version"):
        print(__version__)
        return 0

    command, rest = argv[0], argv[1:]
    if command not in COMMANDS:
        print(f"app-parser: unknown command {command!r}\n\n{USAGE}", file=sys.stderr)
        return 2
    return COMMANDS[command](rest)
