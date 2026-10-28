"""``paramedir`` output of a Dimemas simulation (``*.dm``)."""

from ..histograms import process_category_histogram, split_3d_histogram


def load(entry, case: str, component: str) -> dict:
    """Parse the Dimemas files of one simulation of one component.

    Args:
        entry (src.mapping.Input): Mapping entry with the matched files.
        case (str): Case the files belong to.
        component (str): Component the files belong to.

    Returns:
        dict: Case-level payload under ``Dimemas``, so the summary can list every
        simulated case.

    Raises:
        ValueError: If the entry does not declare its ``simulation`` and ``counter``.
    """
    if not entry.simulation or not entry.counter:
        raise ValueError(
            f"dimemas input for {component}/{case} needs 'simulation' and 'counter'"
        )

    results = {case: {"Dimemas": {entry.simulation: {entry.counter: {}}}}}
    section = results[case]["Dimemas"][entry.simulation][entry.counter]

    for filename in entry.files:
        with open(filename, encoding="utf8") as f:
            histograms = split_3d_histogram(f.read())
        for function_name, histogram in histograms.items():
            section[function_name] = process_category_histogram(histogram)

    return results
