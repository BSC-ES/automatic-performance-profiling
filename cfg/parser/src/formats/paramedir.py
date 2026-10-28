"""Paraver ``paramedir`` output (``*.pm``)."""

from ..histograms import process_category_histogram, split_3d_histogram


def load(entry, case: str, component: str) -> dict:
    """Parse the ``paramedir`` files of one counter of one component.

    The counter category cannot be read from the file, so the mapping must name it in
    ``counter`` (``Time``, ``IPC``, ``MPIcallprofile``, ``PAPI_*``).

    Args:
        entry (src.mapping.Input): Mapping entry with the matched files.
        case (str): Case the files belong to.
        component (str): Component the files belong to.

    Returns:
        dict: Component payload holding the parsed counters.

    Raises:
        ValueError: If the entry does not declare its ``counter``.
    """
    if not entry.counter:
        raise ValueError(
            f"paramedir input for {component}/{case} needs a 'counter' "
            "(e.g. Time, IPC, MPIcallprofile, PAPI_TOT_INS)"
        )

    payload = {"counters": {entry.counter: {}}}
    section = payload["counters"][entry.counter]

    for filename in entry.files:
        with open(filename, encoding="utf8") as f:
            histograms = split_3d_histogram(f.read())
        for function_name, histogram in histograms.items():
            if "std::" in function_name:
                continue
            section[function_name] = process_category_histogram(histogram)

    return payload
