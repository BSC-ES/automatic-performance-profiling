import csv


def get_command_line_instructions():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """
    # Using optparse to enable command line selection of different runtime options
    from optparse import OptionParser

    # Initializing parser
    parser = OptionParser()

    # Adding options
    parser.add_option("-i", "--input-file", dest="input_file", help="data file produced by stream benchmark",
                      default=None)
    parser.add_option("-o", "--output-file", dest="output_file",
                      help="CSV file which contains formatted stream results",
                      default=None)
    (options, args) = parser.parse_args()
    return options.input_file, options.output_file


def stram_output_2csv(stream_data, stream_data_csv):
    with open(stream_data, mode='r') as f:
        line = f.readline().strip()
        while not line.count("Function "):
            line = f.readline().strip()
        # Now we are at the data part
        with open(stream_data_csv, mode='w') as output:
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


if __name__ == "__main__":
    # Get options from command line
    stream_data, stream_data_csv = get_command_line_instructions()
    stram_output_2csv(stream_data, stream_data_csv)
