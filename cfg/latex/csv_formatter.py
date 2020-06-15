
def get_command_line_arguments():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """
    from optparse import OptionParser
    # Parse and assert command line options
    parser = OptionParser()
    parser.add_option("-i", "--input_file", dest="input_file",
                      help="File to be formatted", default=None)
    parser.add_option("-o", "--output_file", dest="output_file",
                      help="File which will retain output", default=None)

    (options, args) = parser.parse_args()
    return options


def formatter(input_file, output_file):
    import csv

    with open(input_file, 'rt') as f_input, open(output_file, 'wt') as f_output:
        csv_input = csv.reader(f_input)
        csv_output = csv.writer(f_output)
        csv_output.writerow(next(csv_input))  # write header

        for cols in csv_input:
            for i in range(1, len(cols[1:]) + 1):
                try:
                    cols[i] = '{:.2f}'.format(float(cols[i]))
                except ValueError:
                    continue
            csv_output.writerow(cols)


if __name__ == "__main__":
    # Get files from command line
    options = get_command_line_arguments()
    file_in = options.input_file
    file_out = options.output_file
    # Call formatter
    formatter(file_in, file_out)
