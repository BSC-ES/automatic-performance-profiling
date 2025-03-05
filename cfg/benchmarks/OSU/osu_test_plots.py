"""
OSU Test Plot Generation Script

This script generates performance plots from OSU benchmark test results. It processes
multiple input files containing benchmark data and creates comparative line plots
showing performance metrics (bandwidth or latency) across different core counts.

The script accepts command line arguments to specify input files and output directory:
    -i, --input-files: Path to folder containing input files (required)
    -o, --output-folder: Path to folder where output plots will be saved

The script expects input files to be formatted according to OSU benchmark output standards,
with the first non-empty line containing the plot title, and subsequent data in two columns
(packet size and performance metric).

Example:
    python OSU_test_plots.py -i "file1.txt file2.txt" -o "./output"

Dependencies:
    - numpy
    - matplotlib
    - argparse
    - os

Output:
    Generates PNG plot files in the specified output directory, with filenames derived
    from the benchmark test titles found in the input files.
"""

import os
import argparse
import numpy as np
import matplotlib.pyplot as plt


def get_command_line_arguments():
    """Parse command line arguments for OSU test plots.

    This function sets up and processes command line arguments for handling input files
    and output folder specification for OSU test plotting functionality.

    Returns:
        argparse.Namespace: A namespace object containing:
            - input_files (str): Path to the folder containing input files
            - output_folder (str): Path to the folder where outputs will be saved

    Raises:
        ArgumentError: If required arguments are not provided
    """

    # Parse and assert command line options
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input-files", dest="input_files", default=None, required=True, nargs="+",
                        help="Name of the folder which contains input")
    parser.add_argument("-o", "--output-folder", dest="output_folder", default=None,
                        help="Name of the folder which will contains outputs")
    return parser.parse_args()


def plot_collective(files: list, folder: str="."):
    """
    Plots collective performance metrics from multiple OSU benchmark files.

    This function creates a line plot comparing performance metrics (bandwidth or latency)
    across different core counts from OSU benchmark output files. The plot is saved as a PNG file.components

    Args:
        files (list, optional): List of file paths containing OSU benchmark results.
                                Each filename should contain core count info.
                                Defaults to empty list.
        folder (str, optional): Directory path where the output plot will be saved.
                                       Defaults to current directory ".".

    Returns:
        None. Saves plot to disk and prints the absolute path of output folder.
    """
    if not files:
        print("No files provided")
        return

    # Set plot title from data's first line
    with open(files[0], encoding="utf8") as f:
        plot_title = f.readline().strip()
        while plot_title == "":
            plot_title = f.readline().strip()
    _, ax = plt.subplots()
    plt.title(plot_title)

    for f in files:
        n_cores = f.split("/")[-1].split(".txt")[0].split("_")[-1]
        try:
            int(n_cores)
        except ValueError:
            print("Filename does not contain info on N cores")
            n_cores = "0"
        x, y = np.loadtxt(f, usecols=(0, 1), comments="#", unpack=True)
        ax.plot(x, y, label=n_cores + " cores")
        ax.legend()

    if plot_title.lower().count("bandwidth"):
        plt.ylabel("Bandwidth [MB/s]- LOGSCALE - the Higher the better")
    elif plot_title.lower().count("latency"):
        plt.ylabel(r"Latency [$\mu$s]- LOGSCALE - the Lower the better")

    plt.xlabel('Packet size (bits) - LOGSCALE')
    plt.grid(True)
    plot_title = plot_title.replace(" / ", "_")
    fig_name = ("_").join(plot_title.split()[2:-2])
    plt.savefig(os.path.join(folder, fig_name + ".png"))

    print("Output saved in ", os.path.abspath(folder))


if __name__ == "__main__":
    # Get files from command line
    options = get_command_line_arguments()
    input_files = options.input_files
    output_folder = options.output_folder

    os.makedirs(output_folder, exist_ok=True)

    plot_collective(input_files, output_folder)
