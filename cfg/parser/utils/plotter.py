from matplotlib.ticker import StrMethodFormatter
import numpy as np



def ransac_test(x: list, y: list) -> tuple[np.array, np.array]:
    """
    Perform RANSAC (RANdom SAmple Consensus) regression to identify inliers and outliers.

    Parameters:
    x (list): A list of x-values (independent variable).
    y (list): A list of y-values (dependent variable).

    Returns:
    tuple[np.array, np.array]: A tuple containing two numpy arrays:
        - inlier_mask: A boolean array indicating which points are inliers.
        - outlier_mask: A boolean array indicating which points are outliers.

    Notes:
    - If the 'sklearn' library is not installed, the function will return arrays indicating all points as inliers and none as outliers.
    - If the length of x is less than 4, the function will print a message and return arrays indicating all points as inliers and none as outliers.
    """
    try:
        from sklearn.linear_model import RANSACRegressor
    except ModuleNotFoundError:
        return np.full(len(x), True), np.full(len(x), False)

    if len(x) < 4:
        print(
            f"Minimum of 4 tests to run the linear regression test")
        return np.full(len(x), True), np.full(len(x), False)

    x = np.array([[i] for i in x])
    y = np.array([[j] for j in y])

    ransac = RANSACRegressor(random_state=42).fit(x, y)

    inlier_mask = ransac.inlier_mask_
    outlier_mask = ~inlier_mask

    return inlier_mask, outlier_mask


def plotter(data, experiment_name, scatter_labels=None, filename=None, linear_test=False):
    """
    Generate a scatter plot comparing two variables and save it as an image.

    This function creates a scatter plot with an optional ideal line and RANSAC-based outlier detection.
    The plot is saved as a PNG file.

    Args:
        data (dict): Dictionary containing two keys (x_label, y_label) with their corresponding data arrays
        experiment_name (str): Name of the experiment, used as default filename if none provided
        scatter_labels (list, optional): Labels for each scatter point. Defaults to None
        filename (str, optional): Output filename for the plot. Defaults to experiment_name + ".png"
        linear_test (bool, optional): If True, performs RANSAC outlier detection. Defaults to False

    Returns:
        None
    """
    try:
        import matplotlib
        matplotlib.use('Agg')
        from matplotlib import pyplot as plt
        import numpy as np
        import os
    except ModuleNotFoundError:
        return

    if filename is None:
        filename = experiment_name + ".png"

    # Plot data
    x_label, y_label = data.keys()
    x, y = data[x_label], data[y_label]

    if linear_test:
        inlier_mask, outlier_mask = ransac_test(x, y)
        plt.scatter(
            x[inlier_mask], y[inlier_mask], color="blue", label="Inliers")
        plt.scatter(
            x[outlier_mask], y[outlier_mask], color="red", label="Outliers")
    else:
        plt.scatter(x, y, alpha=.5)
    plt.plot(x, y, alpha=.25)

    # Plot ideal
    x_min, x_max = min(x), max(x)

    def ideal_speed(cores):
        return y[0]/x[0] * cores

    ideal_range = np.arange(x_min, x_max, 1)
    ideal_speed = [ideal_speed(_x) for _x in ideal_range]
    plt.plot(ideal_range, ideal_speed, ":", alpha=.25, color="k")

    # Format stuff
    plt.title(os.path.splitext(os.path.basename(filename))[0])
    plt.xlabel(x_label)
    plt.ylabel(y_label)

    if not scatter_labels is None:
        for i, label in enumerate(scatter_labels):
            plt.annotate(label, (x[i] + 2, y[i]))

    plt.savefig(filename)
    plt.close()
