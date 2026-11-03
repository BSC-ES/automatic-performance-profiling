"""ICON wall-clock output (``@hpcw-time:``) and its ``Timer report`` table."""

import re

from ..splits import aggregate

SCALABILITY_METRIC = "time"


def parse_icon_timing(timing_fn: str) -> dict:
    """Parse the GNU ``\\time`` output of an ICON run written with ``@hpcw-time:``.

    Only the elapsed wall-clock time is extracted; ICON does not report timesteps or
    SYPD, so the other metrics keep neutral defaults.

    Args:
        timing_fn (str): Path to the ICON timing output file.

    Returns:
        dict: ``time`` in seconds, plus the neutral ``ts_per_second``, ``sypd`` and ``tasks``.
    """
    data = {
        "time": 0.0,
        "ts_per_second": 1.0,
        "sypd": 0.0,
        "tasks": 0
    }
    pattern = r"@hpcw-time:.*?(\d+\.\d+)elapsed"
    with open(timing_fn, "r", encoding="utf8") as f:
        for line in f:
            match = re.search(pattern, line)
            if match:
                data["time"] = float(match.group(1))
                break
    return data


# A timer row starts with its label, optionally prefixed by the "L " level marker,
# followed by the number of calls
ICON_TIMER_ROW = re.compile(r"^\s+(?:L\s+)?([A-Za-z_][\w.:]*)\s+\d+\s")


def _icon_timer_rows(block: str) -> dict:
    """Split one ICON timer table into rows of whitespace-separated tokens.

    ICON wraps the table at about 80 columns, so a logical row spans several physical
    lines: the label and the call count come first, and the remaining columns continue
    on lines that start with a number or a rank marker (``[12]``).

    Args:
        block (str): Text that follows a ``Timer report`` header line.

    Returns:
        dict: Timer label mapped to the full token list of its row.
    """
    rows = {}
    current = None
    for line in block.splitlines():
        match = ICON_TIMER_ROW.match(line)
        if match:
            current = match.group(1)
            rows[current] = line.split()
        elif current is not None and re.match(r"^\s*[\[\d.]", line):
            rows[current].extend(line.split())
    return rows


def _icon_timer_total_avg(tokens: list) -> tuple:
    """Read the ``total avg (s)`` column of an ICON timer row.

    Every row ends with ``<total max rank> <total avg (s)> <# PEs>``, so taking the last
    two tokens yields the column regardless of how the message layer wrapped the line.

    Args:
        tokens (list): Tokens of one row, as returned by ``_icon_timer_rows``.

    Returns:
        tuple: ``(total_avg_seconds, number_of_pes)``, both ``0`` when not parseable.
    """
    if len(tokens) < 2:
        return 0.0, 0
    try:
        return float(tokens[-2]), int(tokens[-1])
    except ValueError:
        return 0.0, 0


def parse_icon_timer_report(timer_fn: str) -> dict:
    """Parse the ICON ``Timer report`` table and return the integration time per PE.

    The ``\\time`` elapsed in ``timing.output`` covers the whole process, including
    start-up and initialisation. ``timer_total`` is started at the beginning of
    ``integrate`` and stopped after the timestep loop, while ``model_init`` runs before
    it, so the ``total`` row of the report is the integration time without the
    initialisation phase.

    Args:
        timer_fn (str): Path to a file holding one or more ICON ``Timer report`` tables.

    Returns:
        dict: Mean ``time`` in seconds, the number of ``tasks`` PEs reported and, when
        the file holds more than one report, the per-report ``splits``.
    """
    data = {"time": 0.0, "tasks": 0}
    with open(timer_fn, "r", encoding="utf8", errors="replace") as timer_f:
        text = timer_f.read()
    if "Timer report" not in text:
        print(f"[WARNING][{timer_fn}] No Timer report found")
        return data

    split_times = []
    for block in text.split("Timer report")[1:]:
        rows = _icon_timer_rows(block)
        if "total" not in rows:
            continue
        total_avg, npes = _icon_timer_total_avg(rows["total"])
        if total_avg > 0:
            split_times.append(total_avg)
        if npes > 0:
            data["tasks"] = npes

    if split_times:
        data["time"] = sum(split_times) / len(split_times)
    if len(split_times) > 1:
        data["splits"] = [{"time": split_time} for split_time in split_times]

    return data


def load_timing(entry, case: str, component: str) -> dict:
    """Parse the ``@hpcw-time:`` outputs of one component.

    Every matched file is one split of the case, so the elapsed times of all of them are
    averaged.

    Args:
        entry (src.mapping.Input): Mapping entry with the matched files.
        case (str): Case the files belong to.
        component (str): Component the files belong to.

    Returns:
        dict: Component payload merged into the case by the caller.
    """
    payloads = [parse_icon_timing(filename) for filename in entry.files]
    return aggregate(payloads, SCALABILITY_METRIC)


def load_timer_report(entry, case: str, component: str) -> dict:
    """Parse the ICON ``Timer report`` files of one component.

    Every matched file is one split of the case, so the integration times of all of them
    are averaged.

    Args:
        entry (src.mapping.Input): Mapping entry with the matched files.
        case (str): Case the files belong to.
        component (str): Component the files belong to.

    Returns:
        dict: Component payload merged into the case by the caller.
    """
    payloads = [parse_icon_timer_report(filename) for filename in entry.files]
    return aggregate(payloads, SCALABILITY_METRIC)
