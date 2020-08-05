import numpy as np
import matplotlib.pyplot as plt
from os.path import abspath
from os import mkdir
import errno
from cfg.latex.ReportGenerator import get_files_from_path


def get_command_line_arguments():
    """
  Returns a list of files that have been provided as a command line argument
  :return: list of files
  """
    from optparse import OptionParser
    # Parse and assert command line options
    parser = OptionParser()
    parser.add_option("-i", "--input-files", dest="input_files", default=None,
                      help="Name of the folder which contains input")
    parser.add_option("-o", "--output-folder", dest="output_folder", default=None,
                      help="Name of the folder which will contains outputs")
    (options, args) = parser.parse_args()

    # In case of not having any argument print help and exit
    if not options.input_files:
        parser.error("An input file must be given")
    return options


def plot_collective(files, output_folder):
    # Set plot title from data's first line
    with open(files[0]) as f:
        plot_title = f.readline().strip()
        while plot_title == "":
            plot_title = f.readline().strip()
    fig, ax = plt.subplots()
    plt.title(plot_title)

    for f in files:
        n_cores = f.split("/")[-1].split(".txt")[0].split("_")[-1]
        try:
            int(n_cores)
        except ValueError:
            print("Filename does not contain info on N cores")
            n_cores = "0"
        x, y = np.loadtxt(f, usecols=(0, 1), comments="#", unpack=True)
        line, = ax.plot(x, y, label=n_cores + " cores")
        ax.legend()
    if plot_title.lower().count("bandwidth"):
        plt.ylabel('Bandwidth [MB/s]- LOGSCALE - the Higher the better')
    elif plot_title.lower().count("latency"):
        plt.ylabel(r'Latency [$\mu$s]- LOGSCALE - the Lower the better')
    plt.xlabel('Packet size (bits) - LOGSCALE')
    plt.grid(True)
    plot_title = plot_title.replace(" / ", "_")
    fig_name = ("_").join(plot_title.split()[2:-2])
    plt.savefig(output_folder + "/" + fig_name + '.png')
    print("Output saved in ", abspath(output_folder))


if __name__ == "__main__":
    # Get files from command line
    options = get_command_line_arguments()
    input_files = options.input_files
    output_folder = options.output_folder
    # Try create output dir
    try:
        mkdir(output_folder)
    except OSError as exc:
        if exc.errno != errno.EEXIST:
            raise
        pass
    files = get_files_from_path(input_files)

    plot_collective(files, output_folder)
