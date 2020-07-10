from os.path import exists


def get_command_line_arguments():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """

    # Parse and assert command line options
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--param-file", default=None,
                        help="Name of the parameter file you want to convert")
    parser.add_argument("-o", "--output-file", default=None,
                        help="Name of the converted parameter file")
    args = parser.parse_args()

    if args.param_file is None:
        parser.error("Path to file missing")
    # check if file exists
    try:
        assert exists(args.param_file)
    except AssertionError:
        raise AssertionError("File %s not found", args.param_file)
    if args.output_file is None:
        out_file = args.param_file.split("/")[-1]
        out_file =  out_file.split(".cfg")[0]
        args.output_file = out_file + "_bash.cfg"
    return args


def convert_file(file_in, output_file):
    f = open(file_in, "r")
    param = [l.replace("\n", "") for l in f if l.count("#") == 0 and l != "\n"]
    f_convert = open(output_file, "w")
    for line in param:
        key, val = line.split("=")
        f_convert.write(key.strip() + "=" + "'" + val.strip() + "'\n")


if __name__ == "__main__":
    # Get files from command line
    options = get_command_line_arguments()
    param_file = options.param_file
    output_file = options.output_file
    convert_file(param_file, output_file)
    print(param_file + " converted in " + output_file)
