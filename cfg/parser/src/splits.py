"""Aggregate the repetitions of a case into a single payload.

A mapping entry may match several files of the same format, for instance
``run_bench_1/*/timing.output``: each of them is one repetition (split) of the same run.
The metric is averaged and the individual values are kept under ``splits``, which the
report uses for its error bars.
"""

import numbers

# Values that identify the run instead of measuring it, so they are never averaged
IDENTITY_KEYS = ("tasks",)


def aggregate(payloads, metric: str) -> dict:
    """Average the payloads of the splits of one case.

    Args:
        payloads (Iterable[dict]): One payload per file, as returned by a loader.
        metric (str): Key the repetitions are measured on (``sypd``, ``time``, ...).
            Its per-split values are kept under ``splits``.

    Returns:
        dict: The averaged payload, with the per-split values under ``splits`` when
        there is more than one.
    """
    payloads = list(payloads)
    if not payloads:
        return {}
    if len(payloads) == 1:
        return payloads[0]

    merged = _average(payloads)
    values = [value for payload in payloads for value in _split_values(payload, metric)]
    if len(values) > 1:
        merged["splits"] = [{metric: value} for value in values]
    return merged


def _split_values(payload: dict, metric: str) -> list:
    """Return the metric of every split a payload reports.

    A payload that already holds several reports (a concatenated file) contributes one
    value per report.
    """
    reported = payload.get("splits")
    if reported:
        return [split[metric] for split in reported if metric in split]
    return [payload[metric]] if metric in payload else []


def _average(payloads: list) -> dict:
    """Average the values of several payloads, recursing into the nested mappings."""
    merged = {}
    for key in dict.fromkeys(key for payload in payloads for key in payload):
        if key == "splits":
            continue
        values = [payload[key] for payload in payloads if key in payload]
        if key in IDENTITY_KEYS:
            merged[key] = values[0]
            if any(value != values[0] for value in values):
                print(f"[WARNING] the splits report different {key}: {values}")
        elif all(isinstance(value, dict) for value in values):
            merged[key] = _average(values)
        elif all(_is_number(value) for value in values):
            merged[key] = sum(values) / len(values)
        else:
            merged[key] = values[0]
    return merged


def _is_number(value) -> bool:
    return isinstance(value, numbers.Real) and not isinstance(value, bool)
