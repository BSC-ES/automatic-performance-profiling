import os
import numpy as np
from scipy.optimize import curve_fit
import matplotlib
matplotlib.use('Agg')
from matplotlib import pyplot as plt


def detect_outliers(nproc, sypd):
    def amdahls_law(n, ymax, p):
        return ymax / ((1 - p) + (p / n))

    popt_sypd, _ = curve_fit(amdahls_law, nproc, sypd)

    sypd_expected = amdahls_law(nproc, *popt_sypd)

    sypd_residuals = sypd - sypd_expected

    # Calculate IQR for residuals
    sypd_q1, sypd_q3 = np.percentile(sypd_residuals, [25, 75]) # [25, 75] interquartile range
    sypd_iqr = sypd_q3 - sypd_q1

    # Dynamic IQR multiplier (more tolerant for larger nproc)
    tolerance = 1.0 

    # Outlier thresholds (SYPD: low values, CHSY: high values)
    sypd_lower = sypd_expected + (sypd_q1 - tolerance * sypd_iqr)

    # Identify outliers
    sypd_outliers = sypd < sypd_lower
    sypd_inliers = sypd >= sypd_lower

    popt_sypd, _ = curve_fit(amdahls_law, nproc[sypd_inliers], sypd[sypd_inliers])
    sypd_expected_no_out = amdahls_law(nproc[sypd_inliers], *popt_sypd)

    return sypd_inliers, sypd_outliers, sypd_expected_no_out


def plotter(data, experiment_name, scatter_labels=None, filename=None, highlight_outliers=False):
    if filename is None:
        filename = experiment_name + ".png"

    # Plot data
    x_label, y_label = data.keys()
    x, y = data[x_label], data[y_label]

    if highlight_outliers:
        inlier_mask, outlier_mask, sypd_expected = detect_outliers(x, y)
        plt.scatter(
            x[inlier_mask], y[inlier_mask], color="blue")
        plt.scatter(
            x[outlier_mask], y[outlier_mask], color="red")
        if any(outlier_mask):
            plt.plot(x[inlier_mask], sypd_expected, ":", alpha=.75, color="k", label="Expected speed")
    else:
        plt.scatter(x, y, alpha=.5, legend=False)
    plt.plot(x, y, alpha=.5, label="Real speed")

    # Plot ideal
    x_min, x_max = min(x), max(x)

    def ideal_speed(cores):
        return y[0]/x[0] * cores

    ideal_range = np.arange(x_min, x_max, 1)
    ideal_speed = [ideal_speed(_x) for _x in ideal_range]
    plt.plot(ideal_range, ideal_speed, ":", alpha=.25, color="k", label="Ideal speed")

    # Format stuff
    plt.title(os.path.splitext(os.path.basename(filename))[0])
    plt.xlabel(x_label)
    plt.ylabel(y_label)

    if not scatter_labels is None:
        for i, label in enumerate(scatter_labels):
            plt.annotate(label, (x[i] + 4, y[i] - 0.2))

    plt.legend()
    plt.savefig(filename)
    plt.close()
