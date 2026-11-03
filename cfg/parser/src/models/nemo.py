"""NEMO timing output (``timing.output``), versions 4 and 5."""

import math
import os
import re

import numpy as np

from ..splits import aggregate

SCALABILITY_METRIC = "sypd"


def parse_nemo_namelist(nemo_namelist_fn: str) -> dict:
    """Parse the ``key = value`` pairs of a NEMO ``namelist_cfg``.

    Args:
        nemo_namelist_fn (str): Path to the namelist file.

    Returns:
        dict: Field name mapped to its value, as written in the file.
    """
    field_ptrn = " *([a-zA-Z0-9_]+)[ ]*=[ ]*([0-9\.E+\-]+)"
    data = {}
    with open(nemo_namelist_fn, "r", encoding="utf8") as nemo_namelist_f:
        for line in nemo_namelist_f:
            field_match = re.search(field_ptrn, line)
            if field_match:
                field_name = field_match.group(1)
                field_value = field_match.group(2)
                data[field_name] = field_value

    return data


def parse_nemo5_timing(timing_fn: str):
    """Parse a NEMO 5 timing output.

    Args:
        timing_fn (str): Path to the timing output.

    Returns:
        dict: Timestep statistics and the time of every reported section.
    """
    step_length_ptrn = "Mean:[ ]*([0-9.e\+\-]+)"
    functions_header_ptrn = "Timing : AVG values over all MPI processes:"
    functions_ptrn = "([0-9a-zA-Z_]+)[ ]*\|[ ]*([0-9.]+)s"
    total_time_ptrn = "avg over all MPI processes = ([0-9.]+)s"

    data = {"total_sim_functions_time": {}, "avg_ts_time": 0,
            "number_ts": 0, "ts_per_second": 0, "sypd": 0, "total_sim_time": 0}

    runtime_path = os.path.dirname(timing_fn)
    namelist_cfg_fn = os.path.join(runtime_path, "namelist_cfg")
    if os.path.exists(namelist_cfg_fn):
        print(f"[INFO][{timing_fn}] Taking parameters from {namelist_cfg_fn}")
        namelist_data = parse_nemo_namelist(namelist_cfg_fn)
    else:
        namelist_data = {}

    with open(timing_fn, "r", encoding="utf8") as timing_f:
        total_time = 0
        ts_per_second = 0
        n_functions_header = 0
        ts_length_seconds = 0

        for line in timing_f:
            step_length_match = re.search(step_length_ptrn, line)
            functions_header_match = re.search(functions_header_ptrn, line)
            functions_match = re.search(functions_ptrn, line)
            total_time_match = re.search(total_time_ptrn, line)

            if total_time == 0 and total_time_match:
                total_time = float(total_time_match.group(1))
            elif ts_per_second == 0 and step_length_match:
                data["avg_ts_time"] = float(step_length_match.group(1)) / 1e6
                ts_per_second = 1 / data["avg_ts_time"]
            elif functions_header_match:
                n_functions_header += 1
            elif n_functions_header == 1 and functions_match:
                function_name, function_net_time = functions_match.groups()
                if function_name != "Section":
                    data["total_sim_functions_time"][function_name] = float(function_net_time)

        if "rn_Dt" in namelist_data:
            ts_length_seconds = float(namelist_data["rn_Dt"])
        if "nn_itend" in namelist_data:
            data["number_ts"] = float(namelist_data["nn_itend"])
        if ts_length_seconds > 0 and data["number_ts"] > 0:
            data["sypd"] = (ts_length_seconds * data["number_ts"]) / (365 * total_time)

        data["total_sim_time"] = total_time
        data["ts_per_second"] = ts_per_second

    return data


def parse_nemo4_timing(timing_fn: str):
    """Parse a NEMO 4 timing output.

    Args:
        timing_fn (str): Path to the timing output.

    Returns:
        dict: Timestep statistics and the time of every reported section.
    """
    step_length_ptrn = "timing step *([0-9]+) *: *(.*)"
    functions_ptrn = "([0-9a-zA-Z_]+) +" + "([0-9\.E\+\-]+) +" * 7 + "([0-9\.E\+\-]+)"
    total_time_ptrn = r"Total *time : +([0-9\.E\+]+) +\(SYPD: +([0-9\.E\+]+) +\) on +MPI +rank +: +([0-9]+)"

    data = {"total_sim_functions_time": {}, "avg_ts_time": 0,
            "number_ts": 0, "ts_per_second": 0, "sypd": 0}

    with open(timing_fn, "r", encoding="utf8") as timing_f:
        steps_length = []
        sypds = []
        number_ts = 1
        npes = 0

        for i, line in enumerate(timing_f):
            step_length_match = re.search(step_length_ptrn, line)
            functions_match = re.search(functions_ptrn, line)
            total_time_match = re.search(total_time_ptrn, line)

            if step_length_match and i != 0:
                number_ts = int(step_length_match.group(1))
                steps_length.append(float(step_length_match.group(2)))
            elif functions_match:
                function_name = functions_match.groups()[0]
                values = [float(v) for v in functions_match.groups()[1:]]
                data["total_sim_functions_time"][function_name] = values[1]
            elif total_time_match:
                _, sypd, npes = total_time_match.groups()
                sypds.append(float(sypd))

        data["avg_ts_time"] = np.average(steps_length)
        data["number_ts"] = number_ts
        data["ts_per_second"] = 1 / data["avg_ts_time"]
        data["sypd"] = np.average(sypds)
        data["tasks"] = int(npes)

    return data


def parse_nemo_timing(timing_fn: str):
    """Parse a NEMO timing output, picking the parser from the reported version.

    Args:
        timing_fn (str): Path to the timing output.

    Returns:
        dict: Timestep statistics and the time of every reported section.

    Raises:
        ValueError: If the NEMO major version is not 4 or 5.
    """
    version_ptrn = "version ([0-9\.]+)"
    nemo_major_version = None
    with open(timing_fn, "r", encoding="utf8") as timing_f:
        for line in timing_f:
            version_match = re.search(version_ptrn, line)
            if version_match:
                nemo_major_version = math.floor(float(version_match.group(1)))
                break

    print(f"[INFO][{timing_fn}] Detected NEMO major version: {nemo_major_version}")
    if nemo_major_version == 4:
        data = parse_nemo4_timing(timing_fn)
    elif nemo_major_version == 5:
        data = parse_nemo5_timing(timing_fn)
    else:
        raise ValueError(f"NEMO version {nemo_major_version} not supported")

    return data


def load(entry, case: str, component: str) -> dict:
    """Parse the NEMO timing files of one component.

    Every matched file is one split of the case, so the metrics of all of them are
    averaged.

    Args:
        entry (src.mapping.Input): Mapping entry with the matched files.
        case (str): Case the files belong to.
        component (str): Component the files belong to.

    Returns:
        dict: Component payload merged into the case by the caller.
    """
    payloads = [parse_nemo_timing(timing_fn) for timing_fn in entry.files]
    return aggregate(payloads, SCALABILITY_METRIC)
