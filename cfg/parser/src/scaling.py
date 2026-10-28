"""Ideal scaling and improvement direction of the scalability metrics used by the reports.

Each metric relates to the amount of resources through an exponent: 1 for throughput
rates, whose value grows with the resources (sypd, sdpd), and -1 for durations, whose
value shrinks with them (time). Speed-up, efficiency and the ideal scaling line are all
derived from that single definition, so a new metric only needs one entry here.
"""

SCALING_EXPONENT = {
    "sypd": 1,
    "sdpd": 1,
    "time": -1,
}

DEFAULT_SCALING_EXPONENT = 1


def scaling_exponent(scalability_variable: str) -> int:
    """Return the exponent relating the metric to the amount of resources.

    Args:
        scalability_variable (str): Name of the metric (e.g. "sypd", "sdpd", "time").

    Returns:
        int: 1 for rates that grow with more resources, -1 for durations that shrink
        with them. Unknown metrics fall back to 1.
    """
    return SCALING_EXPONENT.get(scalability_variable, DEFAULT_SCALING_EXPONENT)


def higher_is_better(scalability_variable: str) -> bool:
    """Return whether a larger value of the metric means better performance.

    Args:
        scalability_variable (str): Name of the metric (e.g. "sypd", "sdpd", "time").

    Returns:
        bool: True for rates, False for durations.
    """
    return scaling_exponent(scalability_variable) > 0


def ideal_value(
    base_value: float, base_nproc: float, nproc: float, scalability_variable: str
) -> float:
    """Return the metric value expected at ``nproc`` processes under perfect scaling.

    Args:
        base_value (float): Metric value of the base case.
        base_nproc (float): Number of processes of the base case.
        nproc (float): Number of processes to evaluate.
        scalability_variable (str): Name of the metric (e.g. "sypd", "sdpd", "time").

    Returns:
        float: Ideal metric value at ``nproc``.
    """
    return base_value * (nproc / base_nproc) ** scaling_exponent(scalability_variable)
