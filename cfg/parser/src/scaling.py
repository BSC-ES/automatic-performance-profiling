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

#: Name of every metric with its unit, as the report writes it in headers, axes and captions.
SCALING_LABEL = {
    "sypd": "SYPD (simulated years per day)",
    "sdpd": "SDPD (simulated days per day)",
    "time": "Integration time (s)",
    "ts_per_second": "Timesteps per second (1/s)",
}


def scalability_label(scalability_variable: str) -> str:
    """Return the name of the metric with its unit, for a header, an axis or a caption.

    Args:
        scalability_variable (str): Name of the metric (e.g. "sypd", "sdpd", "time").

    Returns:
        str: ``"Integration time (s)"`` for ``time``, ``"SYPD (simulated years per day)"``
        for ``sypd``. An unknown metric keeps its capitalised name as it is.
    """
    return SCALING_LABEL.get(scalability_variable, scalability_variable.capitalize())


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
    base_value: float, base_tasks: float, tasks: float, scalability_variable: str
) -> float:
    """Return the metric value expected at ``tasks`` MPI tasks under perfect scaling.

    Args:
        base_value (float): Metric value of the base case.
        base_tasks (float): Number of MPI tasks of the base case.
        tasks (float): Number of MPI tasks to evaluate.
        scalability_variable (str): Name of the metric (e.g. "sypd", "sdpd", "time").

    Returns:
        float: Ideal metric value at ``tasks``.
    """
    return base_value * (tasks / base_tasks) ** scaling_exponent(scalability_variable)
