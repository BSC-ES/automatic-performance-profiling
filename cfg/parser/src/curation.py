"""
Curation of the collected JSON: the tables and plots that make up the report.

Every function takes the ``TimingInformation`` object of one test and writes its output
relative to the current directory, so the report template only has to ask for the file names
it embeds. ``Log`` collects the text of the tables, and ``function_curated_summary`` and the
``*_plot``/``*_summary`` pairs cover the user-function, MPI and scalability views.
"""

import numpy as np
from .plotting import plotter
from .scaling import higher_is_better, scalability_label


class Log:
    """A class to handle text logging with file output capabilities.

    This class provides functionality to accumulate text entries and output them
    either to the console or to a file. It supports both string concatenation
    and method-based text addition.

    Attributes:
        text (str): The accumulated log text.

    Methods:
        __add__(other, newline=True): Adds text to the log, with optional newline.
        add(text, newline=True): Wrapper method for __add__.
        print(file_out=None): Prints log content to console or saves to CSV file.
        save(filename=None): Saves log content to a file or prints to console.
    """

    def __init__(self):
        self.text = ""

    def __add__(self, other: str, newline: bool = True):
        """
        Add text to the current log entry.

        This method allows concatenation of text or another Log object to the current log,
        optionally adding a newline at the end.

        Args:
            other (Union[str, Log]): The text or Log object to append to the current log
            newline (bool, optional): Whether to append a newline character. Defaults to True.

        Returns:
            Log: Returns self for method chaining
        """
        if isinstance(other, Log):
            other = other.text
        self.text += other
        if newline:
            self.text += "\n"
        return self

    def add(self, text: str, newline: bool = True):
        """
        Adds text to the object.

        Args:
            text: The text to be added.
            newline (bool, optional): Whether to append a newline after the text. Defaults to True.

        Returns:
            None
        """
        self.__add__(text, newline)

    def print(self, file_out: str = None):
        """
        Print the contents of the text attribute to a file or stdout.

        This method handles the printing of text content either to a specified file
        (in CSV format) or to standard output if no file is specified.

        Args:
            file_out (str, optional): The path to the output file. If provided, the text
                will be written to this file. If the file extension '.csv' is not present,
                it will be automatically added. Defaults to None.

        Note:
            - If file_out is None, the text will be printed to stdout
            - Underscores in the text content are removed before writing/printing
        """
        if file_out is not None:
            if not file_out.count(".csv"):
                file_out = file_out + ".csv"
            with open(file_out, "wt") as f_output:
                self.text.replace("_", "")
                f_output.write(self.text)
        else:
            print(self.text)

    def save(self, filename: str = None):
        """Save the content of the object either by printing it to stdout or to a file.

        Args:
            filename (str, optional): Path to the output file. If None, prints to stdout. Defaults to None.

        Raises:
            IOError: If there are issues writing to the specified file.
        """
        if filename is None:
            self.print()
        else:
            with open(filename, "w") as f:
                f.write(self.text)


def go_to_dictionary_address(dictionary: dict, address: tuple[str]) -> dict:
    """
    Navigate through a nested dictionary using a list of keys (address).

    Args:
        dictionary (dict): The nested dictionary to navigate.
        address (list): A list of keys representing the path to the desired value.

    Returns:
        The value found at the specified address in the dictionary.

    Raises:
        AssertionError: If any key in the address does not exist in the dictionary.
    """

    def go_to_section(d: dict, section: str):
        try:
            return d[section]
        except KeyError:
            raise AssertionError(
                f"Provided address does not exists in this dictionary:\{address}"
            )

    for step in address:
        dictionary = go_to_section(dictionary, step)
    return dictionary


def function_curated_summary(experiment_data: dict, filename: str):
    """
    Generates a summary of function performance metrics from experiment data and saves it to a file.

    Args:
        experiment_data (dict): An object containing the experiment data, including components and their cases.
        filename (str): The name of the file where the summary will be saved.

    The summary includes:
        - Resources: The number of processors used in each case.
        - Speed-up: The speed-up achieved in each case compared to the base case.
        - Efficiency: The efficiency of resource usage in each case.
    """
    log = Log()

    for component in experiment_data.components:
        fun_results = experiment_data.get_function_info(component)
        for k, v in fun_results.items():
            resources = ""
            speedup = ""
            efficiency = ""

            base_case = experiment_data.components_cases[component][0]
            base_result = fun_results[k][base_case]["elapsed_time"]
            base_tasks = int(fun_results[k][base_case]["tasks"])
            for case in experiment_data.components_cases[component]:
                case_tasks = int(fun_results[k][case]["tasks"])
                case_speed = float(fun_results[k][case]["elapsed_time"])
                resource_increase = case_tasks / base_tasks
                resources += " %.2f" % case_tasks
                speedup += " %.2f" % (base_result / (case_speed + 1e-10))
                efficiency += " %.2f" % (
                    (base_result / (case_speed + 1e-10)) / resource_increase
                )

            log.add("%20s\tResources : %s" % (k, resources))
            log.add("%20s\tSpeed-up  : %s" % ("", speedup))
            log.add("%20s\tEfficiency: %s" % ("", efficiency))
            log.add("_" * 30)

    log.save(filename)


def dimemas_curated_summary(experiment_data: dict) -> Log:
    """
    Generates a curated summary of Dimemas experiment data.

    Args:
        experiment_data (dict): An object containing the experiment data.
            - cases: List of cases in the experiment.
            - base_case: The base case for comparison.
            - data: Nested dictionary containing the experiment data.

    Returns:
        Log: A Log object containing the curated summary of the Dimemas experiment data.

    The summary includes:
        - Wallclock time for each case and experiment.
        - The summary is formatted as a CSV string with cores and wallclock times.
    """

    log = Log()
    cases = experiment_data.cases
    base_case = experiment_data.base_case
    if "Dimemas" not in experiment_data[base_case]:
        print("[WARNING] No Dimemas data in the json; skipping the Dimemas summary")
        return log
    dimemas_experiments = list(experiment_data[base_case]["Dimemas"])
    information_types = list(
        experiment_data[base_case]["Dimemas"][dimemas_experiments[0]].keys()
    )
    information_types = ["Wallclock"]
    log_text = "Cores"
    for de in dimemas_experiments:
        log_text += f",{de}"
    log_text += "\n"

    for case in cases:
        log_text += f"{case}"
        for exp in dimemas_experiments:
            for it in information_types:
                address = (
                    case,
                    "Dimemas",
                    exp,
                    it,
                    "data",
                    "Maximum",
                )

                section = go_to_dictionary_address(experiment_data.data, address)
                wallclock_time = section[0] / 10.0**6
                log_text += f", {wallclock_time:.2f}"
        log_text += "\n"
    log.add(log_text)

    return log


def coupling_info(experiment_data: dict, coupling_folder: str):
    """
    Generate coupling information summary for experiment cases and saves it to CSV files.

    This function processes experiment data for each case, creating a summary table that includes
    performance metrics for individual components and the coupled model. The summary is saved
    as a CSV file in the specified coupling folder.

    Args:
        experiment_data (dict):
            Dictionary containing experiment data with the following structure:
            - cases: list of experiment cases
            - components: list of model components
            - data: nested dictionary with performance metrics for each case and component

    coupling_folder (str): Base directory path where the CSV files will be saved. A subfolder will be created for each case.

    Notes:
        The generated CSV files contain the following columns:
        - component: name of the component or 'coupled' for the coupled model
        - tasks: number of MPI tasks
        - chsy: chunking system information
        - cpl_cost: coupling cost
        - waiting_time: waiting time
        - interpo_time: interpolation time

        The function creates a directory for each case if it doesn't exist and saves
        the summary as 'summary.csv' within that directory.
    """
    import numpy as np
    import os

    for case in experiment_data.cases:
        columns = 6
        # components + model + header
        rows = len(experiment_data.components) + 2
        case_data = np.empty((rows, columns), "U25")
        case_data[0, :] = np.array(
            ["component", "tasks", "chsy", "cpl_cost", "waiting_time", "interpo_time"],
            dtype=str,
        )
        i = 1

        for component in experiment_data.components:
            component_dict = go_to_dictionary_address(
                experiment_data.data, (case, "components", component)
            )
            case_data[i, 0] = component
            for j in range(1, columns):
                case_data[i, j] = str(component_dict[case_data[0, j]])
            i += 1

        case_dict = experiment_data.data[case]
        case_data[i, 0] = "coupled"
        for j in range(1, columns):
            case_data[i, j] = str(case_dict[case_data[0, j]])

        case_folder = os.path.join(coupling_folder, case)
        os.makedirs(case_folder, exist_ok=True)
        np.savetxt(
            os.path.join(case_folder, "summary.csv"), case_data, delimiter=",", fmt="%s"
        )


def fastest_ts_functions(
    experiment_data, case: str, components: list[str]
) -> tuple[float, list[tuple[str, float]]]:
    """Rank the user functions of one case by the time they take in its fastest timestep.

    Args:
        experiment_data: Object holding the parsed experiment data and its ``data`` dictionary.
        case: Name of the case to inspect.
        components: Components whose functions are merged and ranked together.

    Returns:
        tuple[float, list[tuple[str, float]]]: The length of the fastest timestep (s) and the
        ``(function, elapsed_time)`` pairs sorted by descending elapsed time.
    """
    ts_length = 0.0
    functions_elapsed_time = {}
    for component in components:
        component_data = go_to_dictionary_address(
            experiment_data.data, (case, "components", component)
        )
        # Not every model reports the fastest timestep, so fall back to the average one
        ts_length = max(
            float(
                component_data.get(
                    "fastest_ts_time", component_data.get("avg_ts_time", 0.0)
                )
            ),
            ts_length,
        )
        functions_elapsed_time.update(component_data["fastest_ts_functions_time"])

    sorted_functions = sorted(
        functions_elapsed_time.items(), key=lambda function: function[1], reverse=True
    )
    return ts_length, sorted_functions


def generate_most_expensive_function_summary_data(
    experiment_data, out_file_name, length_summary=10, component_to_report=""
):
    """
    Generate a CSV file containing a summary of the most expensive functions in terms of execution time.

    This function processes experiment data to identify and report the functions that consume
    the most execution time, calculating their percentage of the total execution time.

    Args:
        experiment_data: An object containing the performance profiling data with cases,
                        components, and function execution times.
        out_file_name (str): Path to the output CSV file where the summary will be written.
        length_summary (int, optional): Number of top expensive functions to include in the summary.
                                      Defaults to 10.
        component_to_report (str, optional): Specific component to analyze. If empty string,
                                           analyzes all components. Defaults to "".

    Returns:
        None. Writes results to a CSV file with the following columns:
        - function_name: Name of the function
        - case_name (%): Percentage of the fastest timestep of the case spent in the
          function, so the caption of the table, and not its header, says what the
          percentage is taken over

    Note:
        Rows are the union of the per-case summaries, aligned by function name; a case that
        does not report a given function gets a ``-`` in its column.
    """
    import csv
    from os.path import abspath

    components = [component_to_report]
    if component_to_report == "":
        components = experiment_data.components

    header = ["function_name"]
    case_percentages = []
    for case in experiment_data.cases:
        ts_length, sorted_functions = fastest_ts_functions(
            experiment_data, case, components
        )
        header.append(case + " (%)")
        case_percentages.append(
            {
                function_name: f"{elapsed_time / ts_length * 100:.2f}"
                for function_name, elapsed_time in sorted_functions[
                    : length_summary + 1
                ]
            }
        )

    function_names = dict.fromkeys(
        name for case_data in case_percentages for name in case_data
    )

    with open(out_file_name, mode="w", encoding="utf8") as output:
        out_writer = csv.writer(output, delimiter=",")
        out_writer.writerow(header)
        for function_name in function_names:
            out_writer.writerow(
                [function_name]
                + [case_data.get(function_name, "-") for case_data in case_percentages]
            )
        print("Written file in " + abspath(out_file_name))


def most_expensive_function_summary(
    experiment_data: dict, out_file_name: str, length_summary: int = 10
):
    """
    Generate summaries of the most expensive functions for both the entire experiment and individual components.

    Args:
        experiment_data (dict): Dictionary containing the experiment profiling data and component information.
        out_file_name (str): Base name for the output summary files.
        length_summary (int, optional): Number of top expensive functions to include in summaries. Defaults to 10.
    """
    generate_most_expensive_function_summary_data(
        experiment_data, out_file_name, length_summary
    )

    for component in experiment_data.components:
        generate_most_expensive_function_summary_data(
            experiment_data, component + "_" + out_file_name, length_summary, component
        )


def function_time_share_plot(
    experiment_data, out_file_name: str, length_summary: int = 10
) -> None:
    """Plot the time share of the user functions for the whole model and for each component.

    Args:
        experiment_data: Object containing the parsed experiment data.
        out_file_name: Base name of the whole-model png; component plots are prefixed with the
            component name, as the summaries are.
        length_summary (int, optional): Number of most expensive functions plotted per case.
            Defaults to 10.
    """
    import os

    generate_function_time_share_plot(experiment_data, out_file_name, length_summary)

    for component in experiment_data.components:
        dn = os.path.dirname(out_file_name)
        fn = component + "_" + os.path.basename(out_file_name)
        generate_function_time_share_plot(
            experiment_data, os.path.join(dn, fn), length_summary, component
        )


def mpi_profile_share_plot(
    experiment_data, out_file_name: str, length_summary: int = 10
) -> None:
    """Plot the MPI call profile of every component, with one 100% bar per case.

    Args:
        experiment_data: Object containing the parsed experiment data.
        out_file_name: Base name of the png; the component name is prefixed, as the summaries are.
        length_summary (int, optional): Number of most expensive MPI calls plotted per case.
            Defaults to 10.
    """
    import os

    for component in experiment_data.components:
        fn = component + "_" + os.path.basename(out_file_name)
        generate_mpi_profile_share_plot(
            experiment_data, os.path.join(os.path.dirname(out_file_name), fn),
            component, length_summary,
        )


def mpi_call_times(experiment_data, case: str, component: str) -> dict[str, float]:
    """Aggregate the average time of every MPI call over the functions of one case.

    Args:
        experiment_data: Object holding the parsed experiment data and its ``data`` dictionary.
        case: Name of the case to inspect.
        component: Component whose MPI call profile is read.

    Returns:
        dict[str, float]: MPI call (``Outside_MPI``, ``MPI_Recv``, ...) mapped to its time.

    Raises:
        AssertionError: If the case has no MPI call profile for that component.
    """
    component_data = go_to_dictionary_address(
        experiment_data.data, (case, "components", component)
    )
    mpi_profile = go_to_dictionary_address(
        component_data, ("counters", "MPIcallprofile")
    )

    call_times = {}
    for function_data in mpi_profile.values():
        for call, average in zip(function_data["names"], function_data["Average"]):
            call_times[call] = call_times.get(call, 0.0) + float(average)
    return call_times


def generate_mpi_profile_share_plot(
    experiment_data, out_file_name: str, component: str, length_summary: int = 10
) -> None:
    """Plot the share of the MPI call time spent in each MPI call, one 100% bar per case.

    Each case gets one bar that adds up to 100% of the time spent in MPI calls, split into the
    most expensive calls, so the evolution of the MPI profile across the cases can be compared.
    The calls outside the summary are drawn as "Other".

    Args:
        experiment_data: Object containing the parsed experiment data.
        out_file_name (str): Path of the png file to write.
        component (str): Component to plot.
        length_summary (int, optional): Number of most expensive MPI calls plotted per case.
            Defaults to 10.
    """
    shares = {}
    for case in experiment_data.cases:
        try:
            call_times = mpi_call_times(experiment_data, case, component)
        except (AssertionError, KeyError):
            print(
                f"[WARNING] {case} has no MPI call profile for {component}, "
                "it is left out of the MPI profile plot"
            )
            continue

        total_time = sum(call_times.values())
        if total_time <= 0:
            print(
                f"[WARNING] {case} has no MPI call time for {component}, "
                "it is left out of the MPI profile plot"
            )
            continue

        top_calls = sorted(
            call_times.items(), key=lambda call: call[1], reverse=True
        )[:length_summary]
        shares[case] = {call: time / total_time * 100 for call, time in top_calls}

    if not shares:
        print("[WARNING] No MPI call profile to plot, skipping " + out_file_name)
        return

    plot_stacked_shares(
        shares, out_file_name, "Share of the MPI call time (%)", "Other",
        title=f"{component}: share of the MPI call time",
    )


def plot_stacked_shares(
    shares: dict, out_file_name: str, x_label: str, remainder_label: str = "",
    groups: dict = None, dpi: int = 400, title: str = None,
) -> None:
    """Draw one 100% horizontal bar per case, stacked with the given shares.

    Args:
        shares (dict): Case name mapped to ``{label: percentage}``. A label missing in a case is
            skipped, so every bar may hold a different set of labels.
        out_file_name (str): Path of the png file to write.
        x_label (str): Label of the x axis.
        remainder_label (str, optional): Label of the hatched block that fills each bar up to
            100%. Nothing is drawn when the bars already add up to 100%. Defaults to "".
        groups (dict, optional): Bar name mapped to ``(group name, bar label)``. The bars of one
            group are drawn together, under a single group name, with a gap before the next
            group. Every bar is named on its own when absent. Defaults to None.
        dpi (int, optional): Resolution of the png. Defaults to 400.
        title (str, optional): Title of the figure. Defaults to the name of the file, which
            says nothing about what is plotted.
    """
    import os

    import matplotlib
    from matplotlib import pyplot as plt

    # The same label keeps the same colour in every case, ordered by its total share
    total_share = {}
    for case_shares in shares.values():
        for label, share in case_shares.items():
            total_share[label] = total_share.get(label, 0) + share
    labels = [
        label
        for label, _ in sorted(total_share.items(), key=lambda l: l[1], reverse=True)
    ]

    try:
        color_map = matplotlib.colormaps["tab20"]
    except AttributeError:  # matplotlib < 3.6
        color_map = plt.get_cmap("tab20")
    colors = {
        label: color_map(index % color_map.N) for index, label in enumerate(labels)
    }

    # The bars of one group are kept together, with a gap before the next group
    names = list(shares)
    positions = []
    offset = 0.0
    for index, name in enumerate(names):
        if groups is not None and index and groups[name][0] != groups[names[index - 1]][0]:
            offset += 0.7
        positions.append(index + offset)

    fig, ax = plt.subplots(figsize=(9, 1.5 + 0.5 * len(shares)))
    for position, case_shares in zip(positions, shares.values()):
        left = 0.0
        for label in labels:
            share = case_shares.get(label, 0.0)
            if share <= 0:
                continue
            ax.barh(
                position, share, left=left, color=colors[label],
                edgecolor="white", linewidth=0.5,
            )
            if share >= 5:
                ax.text(
                    left + share / 2, position, f"{share:.1f}%",
                    ha="center", va="center", fontsize=7,
                )
            left += share

        remainder = 100 - left
        if remainder <= 0 or remainder_label == "":
            continue
        ax.barh(
            position, remainder, left=left, color="0.85", hatch="//",
            edgecolor="white", linewidth=0.5,
        )
        if remainder >= 5:
            ax.text(
                left + remainder / 2, position, f"{remainder:.1f}%",
                ha="center", va="center", fontsize=7, color="0.35",
            )

    if groups is None:
        ax.set_yticks(positions)
        ax.set_yticklabels(names)
    else:
        # The bar label sits beside its bar and the group name in a column of its own. A tick
        # cannot carry the group name: matplotlib drops a minor tick on top of a major one, so
        # the name of a group with an odd number of bars would hide the middle bar label
        group_positions = {}
        for position, name in zip(positions, names):
            group_positions.setdefault(groups[name][0], []).append(position)
        ax.set_yticks(positions)
        bar_labels = ax.set_yticklabels([groups[name][1] for name in names], fontsize=8)
        ax.tick_params(axis="y", length=0)
        try:
            renderer = fig.canvas.get_renderer()
            bar_label_width = max(
                label.get_window_extent(renderer).width for label in bar_labels
            ) * 72 / fig.dpi
        except (AttributeError, ValueError):  # a canvas that cannot measure its texts
            bar_label_width = 45.0
        for group, group_rows in group_positions.items():
            ax.annotate(
                group,
                xy=(0, sum(group_rows) / len(group_rows)),
                xycoords=("axes fraction", "data"),
                xytext=(-(bar_label_width + 8), 0),
                textcoords="offset points",
                ha="right", va="center", fontweight="bold",
                annotation_clip=False,
            )

    ax.invert_yaxis()
    ax.set_xlim(0, 100)
    ax.set_xlabel(x_label)
    ax.set_title(
        title if title is not None
        else os.path.splitext(os.path.basename(out_file_name))[0]
    )

    handles = [
        plt.Rectangle((0, 0), 1, 1, color=colors[label]) for label in labels
    ]
    if remainder_label != "" and any(
        100 - sum(case_shares.values()) > 0 for case_shares in shares.values()
    ):
        handles.append(plt.Rectangle((0, 0), 1, 1, color="0.85", hatch="//"))
        labels.append(remainder_label)
    ax.legend(
        handles, labels, loc="center left", bbox_to_anchor=(1.01, 0.5),
        fontsize=8, frameon=False,
    )

    fig.tight_layout()
    fig.savefig(out_file_name, dpi=dpi, bbox_inches="tight")
    plt.close(fig)


def generate_function_time_share_plot(
    experiment_data, out_file_name: str, length_summary: int = 10,
    component_to_report: str = ""
) -> None:
    """Plot the share of the fastest timestep spent in each user function.

    Each case gets one bar that adds up to 100% of its fastest timestep, split into the most
    expensive user functions, so the evolution of the percentages across the cases can be
    compared. The part of the timestep that is not covered by a user function is drawn as
    "Not traced".

    Args:
        experiment_data: Object containing the parsed experiment data.
        out_file_name (str): Path of the png file to write.
        length_summary (int, optional): Number of most expensive functions plotted per case.
            Defaults to 10.
        component_to_report (str, optional): Component to plot. If empty string, all components
            are merged. Defaults to "".
    """
    components = [component_to_report]
    if component_to_report == "":
        components = experiment_data.components

    shares = {}
    for case in experiment_data.cases:
        ts_length, sorted_functions = fastest_ts_functions(
            experiment_data, case, components
        )
        if ts_length <= 0:
            print(
                f"[WARNING] {case} has no fastest timestep time, "
                "it is left out of the function time share plot"
            )
            continue
        shares[case] = {
            function: elapsed_time / ts_length * 100
            for function, elapsed_time in sorted_functions[:length_summary]
        }

    if not shares:
        print(
            "[WARNING] No user function time to plot, skipping "
            + out_file_name
        )
        return

    plot_stacked_shares(
        shares,
        out_file_name,
        "Share of the fastest timestep (%)",
        "Not traced",
        title=f"{component_to_report or 'Whole model'}: share of the fastest timestep "
        "spent in each user function",
    )


def function_info_csv(experiment_data: dict, csv_folder: str) -> Log:
    """
    Generate CSV files containing performance metrics for functions in experiment data.

    Args:
        experiment_data (dict): Object containing experimental data with components and function information.
            Must have attributes 'components' and method 'get_function_info'.
        csv_folder (str): Path to the folder where CSV files will be saved. If the folder doesn't exist, it will be created.

    Returns:
        Log: A Log object tracking the execution of the function.

    Notes:
        The CSV files will be named as '{component}_{function}.csv' and will contain:
        - Case: The traced case
        - Tasks: Number of MPI tasks used
        - SpeedUp: Ratio of base case time to current case time, a dimensionless ratio
        - Efficiency: Speedup divided by resource increase ratio, a dimensionless ratio

    The base case is determined by the first case in the function results.
    """
    import os
    from os import mkdir
    from os.path import isdir

    if not isdir(csv_folder):
        mkdir(csv_folder)

    log = Log()

    for component in experiment_data.components:
        fun_results = experiment_data.get_function_info(component)

        for k in fun_results:
            rows = ["Case, Tasks, SpeedUp, Efficiency"]

            base_case = next(iter(fun_results[k]))
            base_result = fun_results[k][base_case]["elapsed_time"]
            base_case_tasks = int(fun_results[k][base_case]["tasks"])
            for case in fun_results[k].keys():
                tasks = int(fun_results[k][case]["tasks"])
                resource_increase = tasks / base_case_tasks
                case_speedup = base_result / (
                    fun_results[k][case]["elapsed_time"] + 1e-10
                )
                case_efficiency = case_speedup / resource_increase
                rows.append(
                    f"{case}, {tasks}, {case_speedup:.2f}, {case_efficiency:.2f}"
                )

            with open(
                os.path.join(csv_folder, component + "_" + k + ".csv"),
                "w",
                encoding="utf8",
            ) as output:
                output.write("\n".join(rows) + "\n")
    return log


def tracking_function_info(experiment_data: dict) -> Log:
    """
    Generate a log of function timing information from experiment data.

    This function creates a formatted log containing elapsed time information for different functions
    across various test cases.

    Args:
        experiment_data (dict): A dictionary containing experimental data with the following structure:
            - cases: List of test case names
            - functions: List of function names
            - Nested timing information accessible via case/function_info/function/Elap. Time(s) paths

    Returns:
        Log: A Log object containing CSV-formatted text with:
            - Headers showing test cases
            - Rows showing elapsed time for each function across test cases
            - Values formatted to 2 decimal places
    """
    log = Log()

    cases = experiment_data.cases
    functions = experiment_data.functions

    info_types = ["Elap. Time(s)"]

    for info_type in info_types:
        log_text = f"{info_type}"
        log_text += "," * len(cases) + "\n"
        log_text += "Functions"
        for case in cases:
            log_text += f",{case}"
        log_text += "\n"

        for function in functions:
            log_text += f"{function}"
            for case in cases:
                address = (
                    case,
                    "ts_function_info",
                    function,
                    info_type,
                )
                section = go_to_dictionary_address(experiment_data, address)
                log_text += f",{section:.2f}"
            log_text += "\n"

        log.add(log_text)
    return log


def function_information_from_paramedir_outputs(
    experiment_data: dict, component: str
) -> tuple[str, dict]:
    """
    Extracts timing information from ParamEDIR experiment outputs for a specific component.
    Args:
        experiment_data (dict): Dictionary containing the experiment data from ParamEDIR
        component (str): Name of the component to analyze

    Returns:
        tuple[str, dict]: A tuple containing:
            - total_time (float): Sum of execution times for all functions in the component
            - functions_time (dict): Dictionary mapping function names to their execution times
    """
    base_case = experiment_data.base_case
    address = (base_case, "components", component)
    component_dictionary = go_to_dictionary_address(experiment_data, address)
    functions_time = {}
    total_time = 0
    for function_name in component_dictionary["counters"]["Time"]:
        function_time = component_dictionary["counters"]["Time"][function_name][
            "Average"
        ][0]
        functions_time |= {function_name: function_time}
        total_time += function_time

    return total_time, functions_time


#: MPI call columns of the per-function scalability table, in reporting order.
MPI_CALL_COLUMNS = (
    "Outside_MPI",
    "MPI_Send",
    "MPI_Recv",
    "MPI_Isend",
    "MPI_Irecv",
    "MPI_Wait",
    "MPI_Waitall",
    "MPI_Bcast",
    "MPI_Barrier",
    "MPI_Reduce",
    "MPI_Allreduce",
    "MPI_Iallreduce",
    "MPI_Alltoall",
    "MPI_Alltoallv",
    "MPI_Gather",
    "MPI_Allgather",
)

#: Hardware counters of the per-function table, in reporting order. ``PAPI_TOT_INS`` is left out
#: because its paramedir configuration is a copy of ``IPC``.
COUNTER_KEYS = ("IPC", "PAPI_TOT_CYC", "PAPI_L1_DCM", "PAPI_L2_DCM", "PAPI_L3_TCM")

#: Unit of every counter, written beside its name in the tables and on the axis of the figures.
#: The cache counters are normalised per thousand instructions, so their value is comparable
#: across functions of different size; ``TOT_CYC`` is the plain number of cycles.
COUNTER_UNITS = {
    "IPC": "instructions per cycle",
    "TOT_CYC": "cycles",
    "L1_DCM": "misses per 1000 instructions",
    "L2_DCM": "misses per 1000 instructions",
    "L3_TCM": "misses per 1000 instructions",
}


def counter_label(counter: str) -> str:
    """Name of a counter in the tables and figures: its PAPI id without the ``PAPI_`` prefix.

    The PAPI id is kept, minus the prefix, because a friendly name such as ``L3 MPKI`` does not
    say which cache the counter measures (``L3_TCM`` is total cache misses, ``L3_DCM`` is data
    cache misses).
    """
    return counter.removeprefix("PAPI_")


def counter_label_with_units(counter: str) -> str:
    """Name of a counter with its unit, e.g. ``L3_TCM (misses per 1000 instructions)``.

    Used wherever the magnitude is reported without any other hint of its unit, i.e. on the
    axis of the counter figures. A counter with no unit in :data:`COUNTER_UNITS` keeps its
    bare name.
    """
    label = counter_label(counter)
    unit = COUNTER_UNITS.get(label)
    return f"{label} ({unit})" if unit else label


def tracked_functions(
    experiment_data, component: str, threshold: float = 0.01
) -> list[str]:
    """User functions of one component that take at least ``threshold`` of the traced time.

    Args:
        experiment_data: Object containing the parsed experiment data.
        component: Component whose functions are ranked.
        threshold (float, optional): Minimum fraction of the traced time of the base case.
            Defaults to 0.01 (1%).

    Returns:
        list[str]: The function names, the most expensive first.
    """
    total_time, functions_time = function_information_from_paramedir_outputs(
        experiment_data, component
    )
    ranked = sorted(functions_time.items(), key=lambda item: item[1], reverse=True)
    return [
        function
        for function, time in ranked
        if total_time > 0 and time / total_time >= threshold
    ]


def tracking(experiment_data, folder, threshold=0.01):
    """
    Write the scalability table of the traced user functions, one per MPI and counter.

    Args:
        experiment_data: Object containing experimental performance data and components
        folder (str): Base output directory path for storing the generated logs
        threshold (float, optional): Minimum fraction of total time a function must
            represent to be included in analysis. Defaults to 0.01 (1%)

    Creates:
        - {folder}/MPI/{component}_functions.csv: MPI call share of each function and case
        - {folder}/counters/{component}_functions.csv: hardware counters of each
          function and case

    Notes:
        Only functions consuming >= threshold % of total time are analyzed, ordered by
        the time they take, so the most expensive function comes first.
    """
    from os import makedirs

    MPI_folder = folder + "/MPI"
    counters_folder = folder + "/counters"
    makedirs(MPI_folder, exist_ok=True)
    makedirs(counters_folder, exist_ok=True)
    for component in experiment_data.components:
        functions = tracked_functions(experiment_data, component, threshold)

        mpi_log = tracking_mpi_scalability(experiment_data, component, functions)
        if mpi_log.text:
            mpi_log.save(f"{MPI_folder}/{component}_functions.csv")

        counter_log = tracking_counter_scalability(
            experiment_data, component, functions
        )
        if counter_log.text:
            counter_log.save(f"{counters_folder}/{component}_functions.csv")


def case_counters(experiment_data, case: str, component: str) -> dict:
    """Counters of one component in one case, empty when the case reports none."""
    return go_to_dictionary_address(
        experiment_data.data, (case, "components", component)
    ).get("counters", {})


def first_average(counter_entry: dict):
    """Average of a counter entry, or None when the function has no value for it."""
    average = (counter_entry or {}).get("Average") or []
    return average[0] if average else None


def function_case_log(
    rows: list[tuple[str, str, dict]],
    columns: list[str],
    formats: dict[str, str] = None,
) -> Log:
    """Draw one row per user function and case, keeping only the columns with a value.

    The user function is written on the first row of its block and left empty on the rows of
    its other cases, so the function name reads once and the report can group the rows.

    Args:
        rows (list): ``(function, case, {column: value})``; a column missing from a row
            is left blank.
        columns (list[str]): Column headers, in reporting order.
        formats (dict, optional): Format spec of the columns that are not two decimals,
            e.g. ``{"TOT_CYC": ".4g"}``.

    Returns:
        Log: The CSV text of the table, header included.
    """
    formats = formats or {}
    keep = [
        column for column in columns
        if any(values.get(column) for _, _, values in rows)
    ]
    lines = [",".join(["User function", "Case"] + keep)]
    previous_function = None
    for function, case, values in rows:
        cells = [
            ""
            if values.get(column) is None
            else format(values[column], formats.get(column, ".2f"))
            for column in keep
        ]
        name = function if function != previous_function else ""
        lines.append(",".join([name, case] + cells))
        previous_function = function

    log = Log()
    log.text = "\n".join(lines)
    return log


def tracking_mpi_scalability(
    experiment_data, component: str, functions: list[str]
) -> Log:
    """MPI call profile of every traced user function, one row per function and case.

    Each value is the share (%) of the time inside the function spent in that MPI call,
    so the rows of one function add up to 100 with ``Outside_MPI``, the time not spent in
    MPI. The header only carries the percent sign; the caption of the table says what the
    percentage is taken over, so no header grows into a sentence.
    """
    columns = [f"{call} (%)" for call in MPI_CALL_COLUMNS]
    rows = []
    for function in functions:
        for case in experiment_data.cases:
            profile = case_counters(experiment_data, case, component).get(
                "MPIcallprofile", {}
            ).get(function, {})
            calls = dict(zip(profile.get("names", []), profile.get("Average", [])))
            rows.append(
                (
                    function,
                    case,
                    {
                        label: calls.get(call)
                        for call, label in zip(MPI_CALL_COLUMNS, columns)
                    },
                )
            )
    return function_case_log(rows, columns)


def tracking_counter_scalability(
    experiment_data, component: str, functions: list[str]
) -> Log:
    """Hardware counters of every traced user function, one row per function and case.

    The counters are the average per thread of each traced case. Every column is the PAPI id
    of its counter without the ``PAPI_`` prefix, and the caption of the table spells out the
    unit of each one (``IPC`` instructions per cycle, ``TOT_CYC`` cycles,
    ``L1_DCM``/``L2_DCM``/``L3_TCM`` misses per thousand instructions), so a header stays a
    bare id of a fixed width instead of a sentence that overflows the column.
    """
    cases_counters = {
        case: case_counters(experiment_data, case, component)
        for case in experiment_data.cases
    }
    keys = [
        key for key in COUNTER_KEYS
        if any(key in counters for counters in cases_counters.values())
    ]
    labels = [counter_label(key) for key in keys]

    rows = []
    for function in functions:
        for case, counters in cases_counters.items():
            rows.append(
                (
                    function,
                    case,
                    {
                        label: first_average(counters.get(key, {}).get(function))
                        for key, label in zip(keys, labels)
                    },
                )
            )
    formats = {
        label: ".4g"
        for key, label in zip(keys, labels)
        if counter_label(key) == "TOT_CYC"
    }
    return function_case_log(rows, labels, formats)


def function_mpi_share_plot(
    experiment_data, out_file_name: str, length_summary: int = 10
) -> None:
    """Plot the MPI call profile of the user functions, one bar per function and case.

    Each bar adds up to 100% of the time spent in one function of one case, split into its MPI
    calls, so the shift from computing (``Outside_MPI``) to waiting in a call is visible for
    every function instead of only for the whole model.

    Args:
        experiment_data: Object containing the parsed experiment data.
        out_file_name (str): Base name of the png; the component name is prefixed.
        length_summary (int, optional): Number of most expensive functions plotted per
            component. Defaults to 10.
    """
    import os

    for component in experiment_data.components:
        try:
            functions = tracked_functions(experiment_data, component)
        except (AssertionError, KeyError):
            print(
                f"[WARNING] {component} has no user function time, "
                "it is left out of the MPI share plot"
            )
            continue

        shares = {}
        groups = {}
        for function in functions[:length_summary]:
            for case in experiment_data.cases:
                profile = case_counters(experiment_data, case, component).get(
                    "MPIcallprofile", {}
                ).get(function, {})
                calls = dict(zip(profile.get("names", []), profile.get("Average", [])))
                calls_to_draw = {
                    call: calls[call] for call in MPI_CALL_COLUMNS if calls.get(call)
                }
                if calls_to_draw:
                    shares[f"{function} {case}"] = calls_to_draw
                    groups[f"{function} {case}"] = (function, case)

        if not shares:
            continue
        file_name = component + "_" + os.path.basename(out_file_name)
        plot_stacked_shares(
            shares,
            os.path.join(os.path.dirname(out_file_name), file_name),
            "Share of the user function time (%)",
            groups=groups,
            dpi=600,
            title=f"{component}: MPI calls of the user functions, "
            "share of the function time",
        )


def function_counter_plot(
    experiment_data,
    out_file_name: str,
    counters: tuple[str, ...] = ("IPC", "PAPI_L3_TCM"),
    length_summary: int = 10,
) -> None:
    """Plot the hardware counters of the user functions along the traced cases.

    One figure per counter and one line per function, with the cases on the x axis labelled by
    the number of processes that ran them, so a counter that degrades with the size of the run
    stands out from one that stays flat. Every counter is written to a file of its own, named
    after it. The cycles are deliberately left out: they fall as the work is split, so they say
    nothing about the efficiency of a function.

    Args:
        experiment_data: Object containing the parsed experiment data.
        out_file_name (str): Base name of the pngs; the component name and the counter key are
            added, ``<component>_<name>_<counter>.png``.
        counters (tuple, optional): Counter keys to plot, one figure each. Defaults to the IPC
            and the L3 misses per thousand instructions.
        length_summary (int, optional): Number of most expensive functions plotted per
            component. Defaults to 10.
    """
    import os

    import matplotlib
    from matplotlib import pyplot as plt

    for component in experiment_data.components:
        try:
            functions = tracked_functions(experiment_data, component)[
                :length_summary
            ]
        except (AssertionError, KeyError):
            print(
                f"[WARNING] {component} has no user function time, "
                "it is left out of the counter plot"
            )
            continue

        cases = []
        tick_labels = []
        for case in experiment_data.cases:
            cases.append(case)
            tasks = go_to_dictionary_address(
                experiment_data.data, (case, "components", component)
            ).get("tasks")
            tick_labels.append(f"{case}\n{tasks} procs" if tasks else case)

        try:
            color_map = matplotlib.colormaps["tab20"]
        except AttributeError:  # matplotlib < 3.6
            color_map = plt.get_cmap("tab20")
        colors = {
            function: color_map(index % color_map.N)
            for index, function in enumerate(functions)
        }

        positions = list(range(len(cases)))
        base_name = os.path.splitext(os.path.basename(out_file_name))[0]
        for key in counters:
            series = {}
            for function in functions:
                values = [
                    first_average(
                        case_counters(experiment_data, case, component)
                        .get(key, {})
                        .get(function)
                    )
                    for case in cases
                ]
                if any(value is not None for value in values):
                    series[function] = [float("nan") if value is None else value
                                        for value in values]
            if not series:
                continue

            figure, axis = plt.subplots(figsize=(6, 3.5))
            for function, values in series.items():
                axis.plot(
                    positions, values, marker="o", linewidth=1.4, label=function,
                    color=colors[function],
                )
            counter_name = counter_label(key)
            axis.set_title(f"{component} {counter_name}")
            axis.set_xlabel("Traced case (MPI tasks)")
            axis.set_ylabel(counter_label_with_units(key))
            axis.set_xticks(positions)
            axis.set_xticklabels(tick_labels, fontsize=8)
            axis.grid(axis="y", linewidth=0.3)
            axis.legend(
                loc="center left", bbox_to_anchor=(1.01, 0.5), fontsize=8,
                frameon=False,
            )

            figure.tight_layout()
            figure.savefig(
                os.path.join(
                    os.path.dirname(out_file_name),
                    f"{component}_{base_name}_{key}.png",
                ),
                dpi=600, bbox_inches="tight",
            )
            plt.close(figure)


def generate_scalability_summary(
    experiment_data: dict, component: str = "", scalability_variable: str = "sypd"
) -> Log:
    """
    Generates a summary of scalability data for a given experiment.

    Args:
        experiment_data (dict): A dictionary containing the experiment data.
        component (str, optional): The specific component to generate the summary for. Defaults to an empty string,
                               which means the summary will be generated for the entire experiment.
        scalability_variable (str, optional): The name of the variable to use for the summary. Defaults to "sypd".

    Returns:
        Log: A Log object containing the summary data with columns: Case, Total Resources,
        Tasks, Threads, {scalability label}, SpeedUp, Efficiency.

        The summary includes:
        - Case: The name of the case.
        - Total Resources: The total processing units of the case (tasks x threads).
        - Tasks: The number of MPI tasks used in the case.
        - Threads: The number of OpenMP threads per task (defaults to 1 when not reported).
        - {scalability_label}: The {scalability_variable} value for the case, with its unit,
          followed by its standard deviation across splits when the case reports them.
        - SpeedUp: The speedup factor compared to the base case, a dimensionless ratio.
          Derived from the direction of the metric: base/case when lower is better
          (e.g. "time"), case/base otherwise (e.g. "sypd", "sdpd").
        - Efficiency: The efficiency of the case, a dimensionless ratio calculated as speedup
          divided by the increase in total compute resources (tasks × threads).

        Cases without a positive value (a run that produced no timing data) are left out of the
        summary, and so are all of them when the base case has no value to compare against.
    """
    log = Log()

    if component == "":
        base_case = experiment_data.base_case
        base_case_data = experiment_data.data[base_case]
        cases = experiment_data.cases
    else:
        cases = experiment_data.components_cases[component]
        base_case = cases[0]
        address = (base_case, "components", component)
        base_case_data = go_to_dictionary_address(experiment_data.data, address)

    base_case_tasks = int(base_case_data["tasks"])
    base_case_threads = int(base_case_data.get("threads", 1))
    base_case_speed = float(base_case_data.get(scalability_variable, 0.0))
    base_case_total_resources = int(base_case_data.get("total_resources", base_case_tasks))

    log.add(
        "Case, Total Resources, Tasks, Threads, "
        + scalability_label(scalability_variable)
        + ", SpeedUp, Efficiency"
    )
    for case in cases:
        if component == "":
            case_data = experiment_data.data[case]
        else:
            address = (case, "components", component)
            case_data = go_to_dictionary_address(experiment_data.data, address)
        speed = float(case_data.get(scalability_variable, 0.0))
        if speed <= 0 or base_case_speed <= 0:
            print(
                f"[WARNING] {case} has no {scalability_variable} value, "
                "it is left out of the scalability summary"
            )
            continue
        case_tasks = int(case_data["tasks"])
        case_threads = int(case_data.get("threads", 1))
        case_total_resources = int(case_data.get("total_resources", case_tasks))
        resource_increase = case_total_resources / base_case_total_resources
        if higher_is_better(scalability_variable):
            speedup = speed / base_case_speed
        else:
            speedup = base_case_speed / speed
        efficiency = speedup / resource_increase

        speed_str = f"{speed:.1f}"
        split_values = [
            float(split[scalability_variable])
            for split in case_data.get("splits", [])
            if scalability_variable in split
        ]
        if split_values:
            speed_str += f" ± {np.std(split_values):.2f}"

        log.add(f"{case}, {case_total_resources}, {case_tasks}, {case_threads}, {speed_str}, {speedup:.1f}, {efficiency:.2f}")

    return log


def scalability_summary(
    experiment_data: dict, filename: str, scalability_variable: str = "sypd"
):
    """
    Generates and saves a summary of scalability metrics for the given experiment data.

    This function creates a summary of the scalability metrics for the entire model and for each component
    within the experiment data. The summaries are saved to the specified filename.

    Args:
        experiment_data (dict): A dictionary containing the experiment data, including components.
        filename (str): The base filename to save the summary data.
        scalability_variable (str, optional): The name of the variable to use for the summary. Defaults to "sypd".

    Returns:
        None
    """
    model_scalability_summary = generate_scalability_summary(
        experiment_data, scalability_variable=scalability_variable
    )
    model_scalability_summary.save(filename)

    for component in experiment_data.components:
        component_scalability_summary = generate_scalability_summary(
            experiment_data, component, scalability_variable=scalability_variable
        )
        component_scalability_summary.save(component + "_" + filename)


def generate_scalability_plot_data(
    experiment_data: dict, component: str = "", scalability_variable: str = "sypd"
) -> dict:
    """
    Generate plot data for scalability performance metric.

    This function processes experiment data to create a dictionary containing x and y values
    for plotting scalability performance against number of processes. It can process either full
    experiment data or data for a specific component.

    Args:
        experiment_data (dict): Dictionary containing experiment data with the following structure:
            - cases: List of case names
            - components_cases: Dictionary mapping component names to their cases
            - data: Dictionary containing performance data for each case

        component (str, optional): Name of the component to analyze. If empty string,
            processes full experiment data. Defaults to "".
        scalability_variable (str, optional): Name of the variable to extract for plotting. Defaults to "sypd".

    Returns:
        dict: Dictionary containing plot data with the following keys:
            - "Number of processes": numpy array of process counts
            - "{scalability_label}": numpy array of {scalability_variable} values, with the unit
              of the metric in the key so the axis cannot be read without it
    """
    x_label = "Number of processes"
    y_label = scalability_label(scalability_variable)
    plot_data = {x_label: np.empty(0), y_label: np.empty(0)}

    if component == "":
        cases = experiment_data.cases
    else:
        cases = experiment_data.components_cases[component]

    for case in cases:
        if component == "":
            case_data = experiment_data.data[case]
        else:
            address = (case, "components", component)
            case_data = go_to_dictionary_address(experiment_data.data, address)
        speed = float(case_data[scalability_variable])
        case_tasks = int(case_data["tasks"])
        plot_data[x_label] = np.append(plot_data[x_label], case_tasks)
        plot_data[y_label] = np.append(plot_data[y_label], speed)

    return plot_data


def scalability_plot(
    experiment_data: dict,
    filename: str,
    scalability_variable: str = "sypd",
    error_bars: bool = False,
):
    """
    Generates and saves plots for scalability data.

    This function creates a plot for the overall experiment data and individual
    component data within the experiment. It uses the `plotter` function from
    the `src.plotting` module to generate the plots.

    Args:
        experiment_data (dict): An object containing the experiment data,
            including the experiment name, cases, and components.
        filename (str): The filename to save the overall plot.
        scalability_variable (str, optional): Metric of the y axis.
        error_bars (bool, optional): Draw the standard deviation of the splits.

    Returns:
        None
    """
    from .plotting import plotter

    metric = scalability_label(scalability_variable)
    plotter(
        data=[experiment_data],
        error_bars=True,
        y_label=scalability_variable,
        y_axis_label=metric,
        x_label="total_resources",
        x_axis_label="Total resources (tasks x threads)",
        title=f"{experiment_data.experiment_name} strong scaling (whole model)",
        filename=filename,
        highlight_outliers=True,
    )

    for component in experiment_data.components:
        plotter(
            data=[experiment_data],
            component=component,
            error_bars=True,
            y_label=scalability_variable,
            y_axis_label=metric,
            x_label="total_resources",
            x_axis_label="Total resources (tasks x threads)",
            title=f"{experiment_data.experiment_name} strong scaling ({component})",
            filename=component + "_" + filename,
            highlight_outliers=True,
        )


def cases_component_data(
    experiment_data: dict, variables_to_report: list[str] = ["tasks"]
):
    """
    Creates a CSV file containing information about the number of MPI tasks
    used by each component in different experiment cases.

    Args:
        experiment_data (dict): Dictionary containing information about experiment cases and components.
            Expected to have the following attributes:
                - components: List of component names
                - cases: List of case names
            And dictionary-like access with structure:
                experiment_data[case]["components"][component]["tasks"]

    Returns:
        None. Creates a file named 'cases_info.csv' with the following format:

            Case,COMPONENT1 tasks,COMPONENT2 tasks,...
            case1,nproc1,nproc2,...
            case2,nproc1,nproc2,...
    """
    log = Log()

    header = "Case"
    for component in experiment_data.components:
        for variable in variables_to_report:
            if len(experiment_data.components) > 1:
                header += f",{component.upper()} "
            else:
                header += ","
            header += variable.replace("_", " ")
    log.add(header)

    for case in experiment_data.cases:
        row = case
        for component in experiment_data.components:
            component_values = experiment_data[case]["components"][component]
            for variable in variables_to_report:
                if variable in component_values:
                    row += f",{component_values[variable]}"
                else:
                    row += ",-"
        log.add(row)

    log.save("cases_info.csv")


def experiment_comparison(experiment1: dict, experiment2: dict) -> Log:
    """
    Compare the performance of two experiments based on their cases.

    This function compares the simulated years per day (SYPD) and time-step length
    for each case in the given experiments. It logs the speed, speedup, efficiency,
    and ratio of the two experiments for each case.

    Args:
        experiment1 (dict): The first experiment data, where keys are case identifiers
                            and values are dictionaries containing "sypd" and "avg_ts_time".
        experiment2 (dict): The second experiment data, with the same structure as experiment1.

    Returns:
        Log: A log object containing the comparison results.
    """
    cases_to_compare = list(
        sorted([c for c in experiment1.cases if c in experiment2.cases])
    )
    base_case = min(cases_to_compare)
    log = Log()

    exp1_base_case_speed = experiment1[base_case]["sypd"]
    exp2_base_case_speed = experiment2[base_case]["sypd"]
    ratio = exp2_base_case_speed / exp1_base_case_speed
    log.add(
        "Base case experiment %4i processes  speed :  %5.1f|%5.1f SYPD                                                    -> %.2f ratio.  "
        % (base_case, exp1_base_case_speed, exp2_base_case_speed, ratio)
    )
    for case in cases_to_compare:
        if case == base_case:
            continue
        resource_increase = case / base_case
        exp1_speed = experiment1[case]["sypd"]
        exp1_speedup = exp1_speed / exp1_base_case_speed
        exp1_efficiency = exp1_speedup / resource_increase
        exp2_speed = experiment2[case]["sypd"]
        exp2_speedup = exp2_speed / exp2_base_case_speed
        exp2_efficiency = exp2_speedup / resource_increase
        ratio = exp2_speed / exp1_speed

        log.add(
            "                     %4i processes  speed :  %5.1f|%5.1f SYPD   SpeedUp:   %4.1fx |%4.1fx   Efficiency: %4.2f|%4.2f  -> %.2f ratio."
            % (
                case,
                exp1_speed,
                exp2_speed,
                exp1_speedup,
                exp2_speedup,
                exp1_efficiency,
                exp2_efficiency,
                ratio,
            )
        )
    exp1_base_length = experiment1[base_case]["avg_ts_time"]
    exp2_base_length = experiment2[base_case]["avg_ts_time"]
    log.add("_" * 30)
    log.add(
        "Base time-step length(s) with %4i processes:    %4.2f | %4.2f"
        % (base_case, exp1_base_length, exp2_base_length)
    )
    for case in cases_to_compare:
        if case == base_case:
            continue
        resource_increase = case / base_case
        exp1_length = experiment1[case]["avg_ts_time"]
        exp2_length = experiment2[case]["avg_ts_time"]
        log.add(
            "                              %4i processes:    %4.2f | %4.2f"
            % (case, exp1_length, exp2_length)
        )
    return log


def multiexperiment_scalability_plot(
    experiments: list, filename: str, scalability_variable: str = "sypd"
):
    plotter(
        data=experiments,
        filename=filename,
        title="Case comparison: "
        + ", ".join(experiment.experiment_name for experiment in experiments),
        highlight_outliers=False,
        plot_ideal=False,
        y_label=scalability_variable,
        y_axis_label=scalability_label(scalability_variable),
        x_label="total_resources",
        x_axis_label="Total resources (tasks x threads)",
        scatter_labels=False,
        error_bars=True,
    )


def multiexperiment_comparison(
    experiments: list, scalability_variable: str = "sypd"
) -> Log:
    """
    Compare multiple experiment results based on a specified field.

    This function analyzes multiple experiments and creates a comparison table of their
    performance metrics for cases with matching total compute resources.

    Args:
        experiments (list): List of TimingInformation objects to compare
        scalability_variable (str): Name of the variable to compare between experiments (e.g. 'sypd')

    Returns:
        Log: A Log object containing the formatted comparison table with the following format:
            - Header row with experiment names
            - Rows for each case showing the scalability_variable value for each experiment

    Notes:
        - Cases are considered matching if they use the same total resources
          (``total_resources = tasks × threads``, with threads defaulting to 1).
        - Every column names the metric with its unit, and the difference of a build with
          the first one is a percentage of the value of the first build.
    """
    log = Log()

    corresponding_cases = [["" for _ in experiments] for _ in experiments[0].cases]
    for i, case in enumerate(experiments[0].cases):
        current_resources = int(experiments[0][case]["total_resources"])
        corresponding_cases[i][0] = case
        for j, experiment in enumerate(experiments[1:]):
            for case in experiment.cases:
                if int(experiment[case]["total_resources"]) == current_resources:
                    corresponding_cases[i][j + 1] = case
                    break

    header = "Resources"
    for i, experiment in enumerate(experiments):
        header += f", {experiment.experiment_name} {scalability_label(scalability_variable)}"
        if i > 0:
            # No comma inside a column name: the header is a row of the csv, so a comma
            # would split the column in two
            header += f" (diff vs {experiments[0].experiment_name} in %)"

    log.add(header)

    for i, case in enumerate(experiments[0].cases):
        case_row = f"{experiments[0][case]['total_resources']}"
        for j, experiment in enumerate(experiments):
            # If there is no corresponding case in the experiment with the same
            # total resources, set invalid value
            exp_speed = -1
            if corresponding_cases[i][j] != "":
                exp_speed = float(
                    experiment[corresponding_cases[i][j]][scalability_variable]
                )
                case_row += f", {exp_speed:.2f}"

                if "splits" in experiment[corresponding_cases[i][j]]:
                    exp_stdev = np.std(
                        [float(split[scalability_variable]) for split in experiment[corresponding_cases[i][j]]["splits"]]
                    )
                    case_row += f" ± {exp_stdev:.2f}"

                if j > 0:
                    base_exp_speed = float(float(experiments[0][corresponding_cases[i][0]][scalability_variable]))
                    exp_diff = (exp_speed - base_exp_speed) / base_exp_speed * 100 if base_exp_speed != 0 else 0
                    case_row += f" ({exp_diff:+.2f})"
            else:
                case_row += ", NA"
        log.add(case_row)

    return log


def generate_weakscaling_data(experiments: list, component_to_report: str = "") -> Log:
    """Generates a log containing weak scaling data from a list of experiments.

    Args:
        experiments (list): List of experiment objects containing performance data.
        component_to_report (str, optional): Specific component to generate report for.
        If empty, reports data for all components. Defaults to "".

    Note:
        The function handles two reporting modes:
        1. All components (component_to_report=""): Reports resolution and grid points for each component
        2. Single component: Reports cores, resolution, timesteps/second, and grid points

        Every column names its unit where the value has one, as the header of a table is the only
        place the report can state it.
    """
    log = Log()

    if component_to_report == "":
        header = "Config"
        for component in experiments[0].components:
            header += f", {component.upper()} Resolution, {component.upper()} Grid points"
    else:
        header = (
            "Config, MPI Tasks, Resolution, Timesteps per second (1/s), Grid points"
        )

    log.add(header)

    for experiment in experiments:
        for case, case_dict in experiment.data.items():
            conf = f"{case}"

            if component_to_report == "":
                case_metrics = case_dict
                log.add(f"{conf}", False)
                for component in experiments[0].components:
                    resolution = case_metrics["components"][component]["resolution"]
                    grid_points = case_metrics["components"][component]["grid_points"]
                    log.add(f", {resolution}, {grid_points}", False)
                log.add("")
            else:
                case_metrics = go_to_dictionary_address(
                    case_dict, ("components", component_to_report)
                )
                grid_points = case_metrics["grid_points"]
                resolution = case_metrics["resolution"]
                tasks = case_metrics["tasks"]
                ts_per_second = float(case_metrics["ts_per_second"])

                log.add(
                    f"{conf}, {tasks}, {resolution}, {ts_per_second:.2f}, {grid_points}"
                )

    return log


def weakscaling_compute(experiments: list, file_out: str) -> None:
    import os

    model_ws_data = generate_weakscaling_data(experiments)
    model_ws_data.save(file_out)

    components = experiments[0].components
    for component in components:
        dn = os.path.dirname(file_out)
        fn = component + "_" + os.path.basename(file_out)
        component_ws_data = generate_weakscaling_data(experiments, component)
        component_ws_data.save(os.path.join(dn, fn))


def find_common_cases_and_functions(experiments):
    common_cases = set(experiments[0].cases)
    for experiment in experiments[1:]:
        common_cases.intersection_update(experiment.cases)
    common_cases = list(common_cases)
    base_case = min(common_cases)

    common_functions = set(experiments[0][base_case]["total_sim_functions_time"].keys())
    for experiment in experiments[1:]:
        common_functions.intersection_update(
            experiment[base_case]["total_sim_functions_time"].keys()
        )
    common_functions = list(common_functions)

    return common_cases, common_functions


def extract_data_from_experiments(experiments):
    from math import ceil

    data = []
    for experiment in experiments:
        for case in experiment.cases:
            to_append = (
                ceil(case / experiment.processes_per_node),
                case,
                experiment[case]["avg_ts_time"],
            )
            data.append(to_append)
    return data


def fit_step_time_to_model(experiments):
    data = extract_data_from_experiments(experiments)
    return fit_data_to_model(data, model=my_model)


def my_model(individual, data):
    import numpy as np

    def time_model(parameter_set, nn, nc):
        A, B, C, D, E = parameter_set
        return A / nn + B / nc + C * np.log(nn) + D * np.log(nc) + E

    def error(parameter_set, experiment_data):
        nn, nc, t = experiment_data
        return (t - time_model(parameter_set, nn, nc)) ** 2

    fitness = 0
    for case in data:
        fitness -= error(individual, case)
    for element in individual:
        if element < 0:
            fitness -= 100000000000
    return fitness


def fit_data_to_model(data, model):
    genetic = True
    if genetic:
        return genetic_optimizer(data, model)
    else:
        return custom_optimizer(data, model)


def genetic_optimizer(data, model):
    from pyeasyga import pyeasyga
    import numpy as np

    ga = pyeasyga.GeneticAlgorithm(
        data,
        elitism=True,
        population_size=100,
        generations=400,
        crossover_probability=0.4,
        mutation_probability=0.5,
    )
    max_time = max([x[2] for x in data])

    def create_individual(data):
        return np.random.uniform(0, max_time, size=5)

    def crossover(parent_1, parent_2):
        parent_1, parent_2 = parent_1.tolist(), parent_2.tolist()
        crossover_index = np.random.randint(0, len(parent_1))
        child_1, child_2 = parent_1, parent_2
        child_1[crossover_index], child_2[crossover_index] = (
            child_2[crossover_index],
            child_1[crossover_index],
        )
        child_1, child_2 = np.array(child_1), np.array(child_2)
        return child_1, child_2

    def mutate(individual):
        index = np.random.randint(0, len(individual))
        individual[index] += np.random.normal(0.05)
        return individual

    ga.fitness_function = model
    ga.create_individual = create_individual
    ga.crossover_function = crossover
    ga.mutate_function = mutate

    ga.run()
    return ga.best_individual()


def custom_optimizer(data, model):
    import numpy as np
    from copy import deepcopy

    max_time = max([x[2] for x in data])

    def create_individual(data):
        return np.random.uniform(0, max_time, size=5)

    my_individual = create_individual(data)
    my_fitness = model(my_individual, data)
    print(my_individual, my_fitness)

    iterations_without_improving = 0
    for i in range(1000000):
        test_individual = deepcopy(my_individual)
        test_individual += np.random.normal(scale=0.01, size=len(my_individual))
        test_fitness = model(test_individual, data)
        if test_fitness > my_fitness:
            my_fitness = test_fitness
            my_individual = deepcopy(test_individual)
            iterations_without_improving = 0
        else:
            iterations_without_improving += 1
        if iterations_without_improving > 1000:
            break
    print(my_individual, my_fitness)
    return my_fitness, my_individual


def fit_functions_to_model(experiments, function_name=None):
    data = get_functions_data(experiments, function_name)
    model_parameters = fit_data_to_model(data, model=my_model)
    return model_parameters


def get_functions_data(experiments, function_name=None):
    from math import ceil

    fun_key = "total_sim_functions_time"
    data = []
    for experiment in experiments:
        base_case = experiment.base_case
        if function_name is None:
            my_fun = list(experiment.data[base_case][fun_key].labels())[0]
        else:
            my_fun = function_name
        for case in experiment.cases:
            to_append = (
                ceil(case / experiment.processes_per_node),
                case,
                experiment[case][fun_key][my_fun]["Elap. Time(s)"],
            )
            data.append(to_append)
    return data


def oversimplified_memory_model(experiments):
    model_parameters = fit_step_time_to_model(experiments)
    error, parameters = model_parameters
    import numpy as np

    error = np.sqrt(abs(error))
    mb, cb, nc, cc, r = parameters
    cb = cb / 48.0
    tt = mb + cb + nc + cc + r
    print("Overall model:")
    print(
        "MB: %.1f%%\tCB: %.1f%%\tError:%.1f%%"
        % (100.0 * mb / tt, 100.0 * cb / tt, 100.0 * error / tt)
    )
    print("Top10 Functions:")
    functions = list(
        experiments[0]
        .data[experiments[0].base_case]["total_sim_functions_time"]
        .labels()
    )
    functions = functions[:10]
    for function in functions:
        error, parameters = fit_functions_to_model(experiments, function_name=function)
        error = np.sqrt(abs(error))
        mb_time, cb_time, internode, intranode, residual = parameters
        cb_time = cb_time / 48
        total_time = mb_time + cb_time + internode + intranode + residual
        print(
            "Function: %20s\tTime(s): %.1f\t MB: %.1f%%\tCB: %.1f%%\tError:%.1f%%"
            % (
                function,
                total_time,
                100.0 * mb_time / total_time,
                100.0 * cb_time / total_time,
                100.0 * abs(error / total_time),
            )
        )
