import csv
from cfg.latex.ReportGenerator import get_files_from_path


def stream_output_2csv(input_files_path):
    csv_files = get_files_from_path(input_files_path, ".txt")

    for cf in csv_files:
        with open(cf, mode='r') as f:
            line = f.readline().strip()
            while not line.count("Function "):
                line = f.readline().strip()
            # Now we are at the data part
            output_file = cf.replace(".txt", ".csv")
            with open(output_file, mode='w') as output:
                out_writer = csv.writer(output, delimiter=',')
                # Write header
                header = [name for name in line.split("  ") if name != ""]
                out_writer.writerow(header)
                # Write Copy
                line = f.readline().strip().replace(":", "")
                out_writer.writerow(line.split())
                # Write Scale
                line = f.readline().strip().replace(":", "")
                out_writer.writerow(line.split())
                # Write Add
                line = f.readline().strip().replace(":", "")
                out_writer.writerow(line.split())
                # Write Triad
                line = f.readline().strip().replace(":", "")
                out_writer.writerow(line.split())


def stream_output_2png(input_files_path, output_picture_name):
    import matplotlib.pyplot as plt
    csv_files = get_files_from_path(input_files_path, ".txt")
    if not csv_files:
        raise Exception("The path %s does not contains any txt files", input_files_path)

    nthreads = []
    function_copy = []
    function_scale = []
    function_add = []
    function_triad = []

    for cf in csv_files:
        nthread = cf.split("_")[-1].split(".")[0]
        try:
            nthread = int(nthread)
        except ValueError:
            raise ValueError("The filename %s does not contains info on nthread", cf)
        nthreads.append(nthread)
    # Order the result for increasing thread
    nthreads.sort()
    for threads in nthreads:
        cf = [f for f in csv_files if int(f.split("_")[-1].split(".")[0]) == threads][0]
        with open(cf, mode='r') as f:
            line = f.readline().strip()
            while not line.count("Function "):
                line = f.readline().strip()
            # Read data
            function_copy.append(f.readline().split()[1].strip())
            function_scale.append(f.readline().split()[1].strip())
            function_add.append(f.readline().split()[1].strip())
            function_triad.append(f.readline().split()[1].strip())
    plt.title("STREAM Benchmark")
    plt.ylabel('Bandwidth [MB/s]')
    plt.xlabel('# Threads')
    plt.plot(nthreads, function_copy, label="Copy")
    plt.plot(nthreads, function_scale, label="Scale")
    plt.plot(nthreads, function_add, label="Add")
    plt.plot(nthreads, function_triad, label="Triad")
    plt.legend(loc='upper left')
    if not output_picture_name.count(".png"):
        output_picture_name = output_picture_name + ".png"
    plt.tight_layout()
    plt.savefig(output_picture_name)


def get_command_line_instructions():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """
    # Using optparse to enable command line selection of different runtime options
    from argparse import ArgumentParser

    # Initializing parser
    parser = ArgumentParser()

    # Adding options
    parser.add_argument("-i", "--input-path",
                        default=None,
                        help="data file produced by stream benchmark")
    parser.add_argument("--csv",
                        default=False, action="store_true",
                        help="Output will produce a csv file")
    parser.add_argument("--png",
                        default=False, action="store_true",
                        help="Output will produce a png file")
    parser.add_argument("-o", "--png-output-name",
                        default=None,
                        help="Name of produced png")
    args = parser.parse_args()

    if args.png_output_name is not None and not args.png:
        parser.error("An output file name can be specified only if pn mode has been enabled")
    if args.png and args.png_output_name is None:
        parser.error("A name must be given for the png.")
    return args


if __name__ == "__main__":
    # Get options from command line
    args = get_command_line_instructions()
    input_path = args.input_path
    csv_output = args.csv
    png_output = args.png
    png_output_name = args.png_output_name
    if csv_output:
        stream_output_2csv(input_path)
    if png_output:
        stream_output_2png(input_path, png_output_name)
