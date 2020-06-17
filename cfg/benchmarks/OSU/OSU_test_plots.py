import numpy as np
import matplotlib.pyplot as plt


def expand_arguments(arguments):
    import glob
    # Using the glob library to make it possible to use wildcards
    expanded_arguments = []
    for arg in arguments:
        if arg.count("*"):
            for new_argument in glob.glob(arg):
                expanded_arguments.append(new_argument)
        else:
            expanded_arguments.append(arg)
    return expanded_arguments


def get_file_list_from_command_line_arguments():
    """
  Returns a list of files that have been provided as a command line argument
  :return: list of files
  """
    from optparse import OptionParser
    # Parse and assert command line options
    parser = OptionParser()
    (options, args) = parser.parse_args()

    files = expand_arguments(args)

    # In case of not having any argument print help and exit
    if not files:
        files = None
    return files, options


def plot_collective(files):
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
    plt.savefig(fig_name + '.png')


if __name__ == "__main__":
    # Get files from command line
    files, options = get_file_list_from_command_line_arguments()
    plot_collective(files)
