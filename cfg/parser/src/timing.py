"""The data model the JSON is serialised from, and the curation entry points.

The class only merges payloads produced by the loaders registered in
:mod:`src.registry`; it never looks at a file name.
"""

import csv
import sys
from os.path import isfile

from .curation import (
    cases_component_data,
    coupling_info,
    dimemas_curated_summary,
    function_counter_plot,
    function_curated_summary,
    function_info_csv,
    function_mpi_share_plot,
    function_time_share_plot,
    most_expensive_function_summary,
    mpi_profile_share_plot,
    scalability_plot,
    scalability_summary,
    tracking,
)
from .merge import dictionary_pointer, merge_dictionaries

# Keys that only make sense under `components`, so they are not copied to the case
_TRACE_ONLY_KEYS = ("counters", "fastest_ts_functions_info", "fastest_ts_functions_time")

#: Axis label of the counters of the scatter plots, with the unit of the raw paramedir value.
#: ``Time`` is the only one that is not a rate: paramedir reports it in milliseconds.
_SCATTER_AXIS_LABEL = {
    "Time": "Time (ms)",
    "IPC": "IPC (instructions per cycle)",
    "PAPI_TOT_INS": "TOT_INS (instructions, scaled in the trace)",
    "PAPI_TOT_CYC": "TOT_CYC (cycles)",
    "PAPI_L1_DCM": "L1_DCM (misses per 1000 instructions)",
    "PAPI_L2_DCM": "L2_DCM (misses per 1000 instructions)",
    "PAPI_L3_TCM": "L3_TCM (misses per 1000 instructions)",
}


def scatter_axis_label(counter: str) -> str:
    """Axis label of a counter of the scatter plots, with its unit.

    Args:
        counter (str): Counter key, as named in the paramedir configuration.

    Returns:
        str: The counter with its unit, or the key itself when the unit is not known.
    """
    return _SCATTER_AXIS_LABEL.get(counter, counter)


class TimingInformation:
    """Performance metrics of one test, keyed by case and component.

    Args:
        experiment_name (str, optional): Name of the test.
        param_file (str, optional): ``param.cfg`` with ``processes_per_node`` and
            ``configuration_name``.
        processes_per_node (int, optional): Defaults to 48.
        components (list, optional): Components the report knows about.
    """

    def __init__(self, experiment_name=None, param_file=None, processes_per_node=48,
                 components=None):
        self.experiment_name = experiment_name
        self.cases = None
        self.base_case = None
        self.processes_per_node = processes_per_node
        self.functions = None
        self.param_file = self.load_param(param_file)
        self.data = {}
        self.components = components or []
        self.components_cases = None

    def __getitem__(self, item):
        return self.data[item]

    def add_case(self, payload: dict):
        """Merge a case-level payload, as returned by the case formats.

        Args:
            payload (dict): ``{case: {...}}`` as returned by the format loader.
        """
        self.data = merge_dictionaries(self.data, payload)

    def add_component(self, case: str, component: str, payload: dict, tasks: int = None):
        """Merge the payload of one component into a case.

        Args:
            case (str): Case the payload belongs to.
            component (str): Component the payload belongs to.
            payload (dict): Values returned by the format loader.
            tasks (int, optional): Overrides the number of MPI tasks of the component.
        """
        existing = self.data.get(case, {}).get("components", {}).get(component, {})
        for key, value in payload.items():
            # Nested sections merge key by key, so only scalars can be hidden
            if key in existing and not isinstance(value, dict) and existing[key] != value:
                print(f"[WARNING] {case}/{component}: keeping {key}={existing[key]!r} "
                      f"declared for the case, the file reports {value!r}", file=sys.stderr)

        self.data = merge_dictionaries(
            self.data, {case: {"components": {component: payload}}}
        )
        if tasks is not None:
            dictionary_pointer(self.data, (case, "components", component))["tasks"] = tasks

        ts_per_second = payload.get("ts_per_second")
        if ts_per_second is not None:
            case_data = dictionary_pointer(self.data, (case,))
            previous = case_data.get("ts_per_second")
            case_data["ts_per_second"] = (
                ts_per_second if previous is None else min(ts_per_second, previous)
            )

    def finalize(self):
        """Close the merge: order the cases, flatten a single component, find functions."""
        if len(self.components) == 1:
            self._merge_single_component()
        self._compute_total_resources()
        self._setup_cases()
        if self._has_counters():
            self._derive_function_times()
            self.functions = self.find_functions()

    def _compute_total_resources(self):
        """Set ``total_resources = tasks × threads`` on every case and component.

        Threads default to 1 when the field is absent.  Users may supply
        ``total_resources`` instead of ``tasks``; in that case ``tasks`` is
        derived as ``total_resources / threads`` (or ``total_resources`` when
        threads is 1).
        """
        for case_data in self.data.values():
            threads = int(case_data.get("threads", 1))

            if "tasks" not in case_data and "total_resources" in case_data:
                # total_resources provided instead of tasks
                total = int(case_data["total_resources"])
                case_data["tasks"] = total // threads
                case_data["total_resources"] = total
            elif "tasks" in case_data:
                case_data["total_resources"] = int(case_data["tasks"]) * threads
            else:
                # No resource info at all — skip
                continue

            for component in self.components:
                try:
                    comp_data = case_data["components"][component]
                    comp_threads = int(comp_data.get("threads", 1))
                    if "tasks" not in comp_data and "total_resources" in comp_data:
                        total = int(comp_data["total_resources"])
                        comp_data["tasks"] = total // comp_threads
                        comp_data["total_resources"] = total
                    elif "tasks" in comp_data:
                        comp_data["total_resources"] = int(comp_data["tasks"]) * comp_threads
                except KeyError:
                    continue

    def _merge_single_component(self):
        """Copy the values of the only component to the case, as the reports expect.

        The trace-only sections stay under the component, where the curation reads them.
        """
        component = self.components[0]
        for case_data in self.data.values():
            payload = case_data.get("components", {}).get(component)
            if payload is None:
                continue
            merge_dictionaries(
                case_data,
                {k: v for k, v in payload.items() if k not in _TRACE_ONLY_KEYS},
            )

    def _has_counters(self) -> bool:
        return any(
            "counters" in component
            for case_data in self.data.values()
            for component in case_data.get("components", {}).values()
        )

    def _derive_function_times(self):
        """Store the timestep time of every traced function, in seconds."""
        for case in self.cases:
            for component in self.components:
                component_dict = dictionary_pointer(self.data, (case, "components", component))
                if "counters" not in component_dict:
                    print(f"[WARNING] No counters found in paramedir data for case {case} component {component}")
                    continue
                if "Time" not in component_dict["counters"]:
                    print(f"[WARNING] No Time counters found in paramedir data for case {case} component {component}")
                    continue
                component_dict["fastest_ts_functions_time"] = {
                    function_name: values["Average"][0] / 1e3
                    for function_name, values in component_dict["counters"]["Time"].items()
                }

    def _ordered_cases(self, component: str = None):
        """Order the loaded cases by their number of tasks.

        Args:
            component (str, optional): Component to take the number of tasks from.
                If not provided, the total number of tasks of the case is used.

        Returns:
            list: Case names ordered by number of tasks when every case reports it,
                  otherwise the cases in the order in which they were loaded.
        """
        cases_tasks = []
        for case, case_data in self.data.items():
            if component is not None:
                case_data = case_data.get("components", {}).get(component, {})
            if "tasks" not in case_data:
                # Any input file without the number of tasks keeps the cases as they
                # come in, so the experiment can still be reported
                return list(self.data.keys())
            cases_tasks.append((int(case_data["tasks"]), case))

        return [case for _, case in sorted(cases_tasks)]

    def _setup_cases(self):
        """Initialize the cases, base_case and components_cases attributes."""
        self.cases = self._ordered_cases()
        if self.cases:
            self.base_case = self.cases[0]

        self.components_cases = {component: self._ordered_cases(component)
                                 for component in self.components}

    def find_functions(self) -> list:
        """Return the traced function names found in the ``Time`` counters."""
        functions = set()
        for case in self.cases:
            for component in self.components:
                try:
                    functions.update(
                        self.data[case]["components"][component]["counters"]["Time"]
                    )
                except KeyError:
                    continue
        return sorted(functions)

    def get_function_info(self, component: str = "") -> dict:
        """Retrieve function information for all cases or for a specific component.

        Args:
            component (str, optional): Component to retrieve information for. If not
                provided, every component is reported.

        Returns:
            dict: Function name mapped to ``{case: {"tasks": int, "elapsed_time": float}}``.
        """
        ret_val = {}
        if component == "":
            components = self.components
            cases = self.cases
        else:
            components = [component]
            cases = self.components_cases[component]

        for component_name in components:
            for function in self.functions:
                ret_val[function] = {}
                for case in cases:
                    tasks = self[case]["components"][component_name]["tasks"]
                    ret_val[function][case] = {
                        "tasks": tasks, "elapsed_time": 0}
                    try:
                        ret_val[function][case]["elapsed_time"] = self[case]["components"][component_name]["fastest_ts_functions_info"][function]
                    except KeyError:
                        del ret_val[function]
                        break
        return ret_val

    def load_param(self, param_file) -> dict:
        """Load the ``key=value`` parameters of the test.

        Args:
            param_file (str): Path to the parameter file.

        Returns:
            dict: Parameter name mapped to its list of values, or ``None``.

        Raises:
            AssertionError: If the parameter file does not exist.
        """
        if param_file is None:
            return None

        try:
            assert isfile(param_file)
        except AssertionError:
            raise AssertionError("parameter file %s not found", param_file)

        with open(param_file, "r") as f:
            param = [line.replace("\n", "")
                     for line in f if line.count("#") == 0 and line != "\n"]
        param_dictionary = {}
        for line in param:
            key, val = line.split("=")
            if len(val) > 2 and val[0] == "\'" and val[-1] == "\'":
                val = val[1:-1]
            param_dictionary[key.strip()] = val.strip().split(" ")

        try:
            ppn = param_dictionary['processes_per_node'][0]
            self.processes_per_node = ppn
        except KeyError:
            pass

        if self.experiment_name is None:
            try:
                self.experiment_name = param_dictionary['configuration_name'][0]
            except KeyError:
                pass
        return param_dictionary

    def function_summary(self, filename):
        return function_curated_summary(self, filename)

    def most_expensive_function_summary(self, out_file_name):
        return most_expensive_function_summary(self, out_file_name)

    def function_time_share_plot(self, out_file_name):
        return function_time_share_plot(self, out_file_name)

    def mpi_profile_share_plot(self, out_file_name):
        return mpi_profile_share_plot(self, out_file_name)

    def function_mpi_share_plot(self, out_file_name):
        return function_mpi_share_plot(self, out_file_name)

    def function_counter_plot(self, out_file_name, counters=("IPC", "PAPI_L3_TCM")):
        return function_counter_plot(self, out_file_name, counters)

    def scatter_plots(self, x_axis: str = "L3", y_axis: str = "IPC", length_summary: int = 10):
        """Plot two counters of the tracked functions, one file per component.

        Args:
            x_axis (str): Counter on the x-axis.
            y_axis (str): Counter on the y-axis.
            length_summary (int): Number of functions to track.

        Raises:
            KeyError: If a function name is not present in the trace data.
        """
        import re
        import matplotlib.pyplot as plt
        import numpy as np

        function_info = {}
        n_function = 0
        for component in self.components:
            function_info[component] = {}
            for f_name in self.functions:
                if n_function == length_summary:
                    break
                function_info[component][f_name] = {'x': [], 'y': []}
                n_function += 1
                for case in self.components_cases[component]:
                    try:
                        x_data = self.data[case]["components"][component]["counters"][x_axis][f_name]['Average']
                        y_data = self.data[case]["components"][component]["counters"][y_axis][f_name]['Average']
                    except KeyError:
                        del function_info[component][f_name]
                        n_function -= 1
                        break

                    function_info[component][f_name]['x'] += x_data
                    function_info[component][f_name]['y'] += y_data

        for component_name, component_function_info in function_info.items():
            output_name = component_name + "-" + x_axis + "-" + y_axis + ".png"

            fig, ax = plt.subplots()
            case_str = ""
            for i, case in enumerate(self.components_cases[component_name]):
                if i != 0:
                    case_str += " - "
                case_str += case
            ax.set_title(
                f"{scatter_axis_label(x_axis)} against {scatter_axis_label(y_axis)}"
                f" in {component_name} (one point per function and case)\n{case_str}")
            ax.set_xlabel(scatter_axis_label(x_axis))
            ax.set_ylabel(scatter_axis_label(y_axis))
            for i, f_name in enumerate(component_function_info):
                if f_name[0] == "_":
                    legend_name = re.sub('^_+', "", f_name)
                else:
                    legend_name = f_name
                x = component_function_info[f_name]['x']
                y = component_function_info[f_name]['y']
                u = np.diff(x)
                v = np.diff(y)
                pos_x = x[:-1]
                pos_y = y[:-1]

                c = np.full(len(x), i / len(component_function_info))
                ax.quiver(pos_x, pos_y, u, v, angles="xy", pivot="tail", headlength=2,
                          headaxislength=2, scale_units="xy", scale=1, color=plt.cm.tab20(c))
                ax.scatter(x, y, marker="o", label=legend_name,
                           c=plt.cm.tab20(c), edgecolors="black")

            if len(component_function_info) == 0:
                ax.text(
                    0.5, 0.5, f"{x_axis} vs {y_axis} not available", ha="center", va="center")

            ax.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
            fig.savefig(output_name, bbox_inches='tight', dpi=400)

    def dimemas_summary(self):
        return dimemas_curated_summary(self)

    def function_info_csv(self, csv_folder):
        function_info_csv(self, csv_folder)

    def scalability_summary(self, filename, scalability_variable="sypd"):
        return scalability_summary(self, filename, scalability_variable=scalability_variable)

    def scalability_plot(self, filename=None, scalability_variable="sypd"):
        return scalability_plot(self, filename, scalability_variable=scalability_variable)

    def tracking(self, folder):
        return tracking(self, folder)

    def coupling_info(self, folder):
        return coupling_info(self, folder)

    def cases_component_data(self, variables_to_report: list):
        return cases_component_data(self, variables_to_report)

    def save_json(self, filename: str = None):
        """Save the object to a JSON file.

        Args:
            filename (str, optional): Name of the file. Defaults to the experiment name
                and then to ``experiment.json``. A ``.json`` extension is appended when
                missing.
        """
        import json
        if filename is None:
            if self.experiment_name is not None:
                filename = self.experiment_name + ".json"
            else:
                filename = "experiment.json"
        if not filename.count(".json"):
            filename = filename + ".json"
        dictionary_to_save = {
            "experiment_name": self.experiment_name,
            "data": self.data,
            "cases": self.cases,
            "base_case": self.base_case,
            "processes_per_node": self.processes_per_node,
            "functions": self.functions,
            "param_file": self.param_file,
            "components": self.components,
            "components_cases": self.components_cases,
        }

        with open(filename, "w", encoding="utf8") as f:
            json.dump(dictionary_to_save, f)

    def load_json(self, filename: str):
        """Load a JSON file written by :meth:`save_json`.

        Args:
            filename (str): Path to the JSON file.

        Raises:
            KeyError: If any of the required keys is missing.
        """
        import json

        def json_keys2int(x):
            if isinstance(x, dict):
                try:
                    return {int(k): v for k, v in x.items()}
                except ValueError:
                    return dict(x.items())
            return x

        with open(filename, "r", encoding="utf8") as f:
            json_data = json.load(f, object_hook=json_keys2int)
        self.experiment_name = json_data["experiment_name"]
        self.data = json_data["data"]
        self.cases = json_data["cases"]
        self.base_case = json_data["base_case"]
        self.processes_per_node = json_data["processes_per_node"]
        self.functions = json_data["functions"]
        self.components = json_data["components"]
        self.components_cases = json_data["components_cases"]
        try:
            self.param_file = json_data["param_file"]
        except KeyError:
            pass
