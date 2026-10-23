import os
import numpy as np
from scipy.optimize import curve_fit
import matplotlib

matplotlib.use("Agg")
import matplotlib.colors as mcolors
from matplotlib import pyplot as plt

from cfg.parser.utils.scalability import ideal_value


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


def detect_outliers(nproc, sypd):
    def amdahls_law(n, ymax, p):
        return ymax / ((1 - p) + (p / n))

    popt_sypd, _ = curve_fit(amdahls_law, nproc, sypd)

    sypd_expected = amdahls_law(nproc, *popt_sypd)

    sypd_residuals = sypd - sypd_expected

    sypd_q1, sypd_q3 = np.percentile(sypd_residuals, [25, 75])
    sypd_iqr = sypd_q3 - sypd_q1

    tolerance = 1.0
    sypd_lower = sypd_expected + (sypd_q1 - tolerance * sypd_iqr)

    sypd_outliers = sypd < sypd_lower
    sypd_inliers = sypd >= sypd_lower

    popt_sypd, _ = curve_fit(amdahls_law, nproc[sypd_inliers], sypd[sypd_inliers])
    expected_sypd = amdahls_law(nproc, *popt_sypd)

    return sypd_inliers, sypd_outliers, expected_sypd


def plotter(
    data: list,
    component: str = "",
    x_label: str = "nproc",
    y_label: str = "sypd",
    filename=None,
    highlight_outliers=False,
    plot_ideal=True,
    scatter_labels=True,
    error_bars=False,
):
    multiexperiment_name = ""

    for experiment in data:
        experiment_name = experiment.experiment_name
        multiexperiment_name += experiment_name + "-"

        if component == "":
            cases = experiment.cases
        else:
            cases = experiment.components_cases[component]

        x_max_length = 0

        x, y, y_err = np.array([]), np.array([]), np.array([])
        plotted_cases = []
        for case in cases:
            if component == "":
                case_data = experiment.data[case]
            else:
                address = (case, "components", component)
                case_data = go_to_dictionary_address(experiment.data, address)

            if y_label not in case_data:
                print(
                    f"[WARNING] {case} has no {y_label} value, "
                    "it is left out of the scalability plot"
                )
                continue
            x = np.append(x, case_data[x_label])
            y = np.append(y, case_data[y_label])
            plotted_cases.append(case)

            if error_bars and "splits" in case_data:
                split_values = [
                    split[y_label]
                    for split in case_data["splits"]
                    if y_label in split
                ]
                if split_values:
                    y_err = np.append(y_err, np.std(split_values, axis=0))

        if x.size == 0:
            continue

        plt.plot(x, y, "-", alpha=0.5, label=f"{experiment_name} real speed")

        if highlight_outliers and len(x) > 4:
            inlier_mask, outlier_mask, expected_sypd = detect_outliers(x, y)
            plt.scatter(x[inlier_mask], y[inlier_mask], color="blue", marker=".")
            plt.scatter(x[outlier_mask], y[outlier_mask], color="red", marker=".")
            if any(outlier_mask):
                plt.plot(
                    x,
                    expected_sypd,
                    ":",
                    alpha=0.75,
                    color="k",
                    label=f"{experiment_name} expected speed",
                )
        else:
            plt.scatter(x, y, marker=".")

        if error_bars and len(y_err) == len(y):
            line_color = plt.gca().lines[-1].get_color()
            line_color_rgb = np.array(mcolors.to_rgb(line_color))
            darker_color = mcolors.to_hex(line_color_rgb * 0.6)
            plt.errorbar(
                x,
                y,
                yerr=y_err,
                fmt="none",
                ecolor=darker_color,
                alpha=1,
                label=f"{experiment_name} real speed error bars",
            )

        x_min, x_max = min(x), max(x)
        y_min, y_max = min(y), max(y)
        x_range = abs(float(x_max) - float(x_min))
        y_range = abs(float(y_max) - float(y_min))
        if plot_ideal:
            ideal_range = np.arange(x_min, x_max, 1)
            ideal_values = [
                ideal_value(y[0], x[0], _x, y_label) for _x in ideal_range
            ]
            plt.plot(
                ideal_range,
                ideal_values,
                ":",
                alpha=0.25,
                color="k",
                label=f"{experiment_name} ideal speed",
            )

        plt.xlabel(x_label)
        plt.ylabel(y_label)

        if len(x) > x_max_length:
            plt.xticks(x, [int(_x) for _x in x])
            x_max_length = len(x)

        if scatter_labels:
            for i, label in enumerate(plotted_cases):
                plt.annotate(label, (x[i] + x_range * 0.03, y[i] - y_range * 0.05))

    if filename is None:
        filename = multiexperiment_name[:-1] + ".png"

    plt.title(os.path.splitext(os.path.basename(filename))[0])
    plt.legend()
    plt.savefig(filename, dpi=400)
    plt.close()
