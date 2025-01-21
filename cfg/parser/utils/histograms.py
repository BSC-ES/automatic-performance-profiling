# This file contains several resources to read and parse paramedir outputs.


from os.path import join
import re

# List of different accumulated results given by paramedir
paramedir_labels = ("Total",
                    "Average",
                    "Maximum",
                    "Minimum",
                    "StDev",
                    "Avg/Max",
                    )


def split_3d_histogram(text3d):
    lines = text3d.split("\n")
    count = 0
    starts, ends = [], []

    # Find starts and ends of each histogram assuming that last line will be "Avg/Max"
    starts.append(0)
    for index, line in enumerate(lines):
        if line.count("Avg/Max"):
            ends.append(index)
            starts.append(index + 1)
            count += 1
    # Remove last start
    starts.pop(-1)

    histograms = {}
    # For each histogram
    for s, e in zip(starts, ends):
        case_lines = [l for l in lines[s:e + 1] if l.strip()]
        # with extended flags long names are stored btw square brackets
        name = case_lines[0].split("[")[-1]
        # Replace closing bracket if present
        name = name.replace("]", "")
        name = name.lower().split("_mp_")[-1]
        if name[-1] == "_":
            name = name[:-1]
        # name = case_lines[0].strip()
        histogram = "\n".join(case_lines[1:])
        histograms[name] = histogram
    # In case of having a single histogram, fix it
    if len(histograms) == 1:
        for key in histograms.keys():
            histograms = {"data": key + "\n" + histograms[key]}
    return histograms


def process_time_histogram(histogram):
    # Returning a single value
    # Read header line with function aliases and add index to the dictionary
    lines = histogram.split("\n")
    index_line = lines[0]
    indexes = index_line.split()

    times = {}
    for index, line in enumerate(lines):
        if not line.strip():
            continue
        split_line = line.split()
        if split_line[0] in paramedir_labels:
            key = split_line[0]
            times[key] = [float(_x) for _x in split_line[1:]][0]

    return times


def process_category_histogram(histogram):
    lines = [l for l in histogram.split("\n") if l.strip()]
    # Read header line with category labels
    category_labels = lines[0]
    # Fix problem with unnamed values
    pattern = "value [0-9]+"
    m = re.findall(pattern=pattern, string=category_labels)
    for match in m:
        replacement = match.replace(" ", "_")
        category_labels = category_labels.replace(match, replacement)
    # TODO: Solve this hardcoded fix with a more general solution to deal with (non-)csv paramedir outputs.
    category_labels = category_labels.replace("Outside MPI", "Outside_MPI")
    # Get list of funciont names
    categories = category_labels.split()

    to_return = {"names": categories}

    for index, line in enumerate(lines):
        if not line.strip():
            continue
        split_line = line.split()
        label = split_line[0]
        if label in paramedir_labels:
            to_return[label] = [float(_x) for _x in split_line[1:]]

    # We'll filter out all the unnamed values
    indices_to_keep = [index for index, value in enumerate(
        categories) if value.count("value_") == 0]
    for key in to_return.keys():
        to_return[key] = [v for index, v in enumerate(
            to_return[key]) if index in indices_to_keep]
    return to_return


def digest_function_information(information, function_data):
    pass


def compute_histogram_data(histogram_files):
    histogram_data = {}
    for counter, counter_file in histogram_files.items():
        counter_file_path = join(data_folder, counter_file)

        with open(counter_file_path) as f:
            h3d_text = f.read()
            histograms = split_3d_histogram(h3d_text)

        histogram_data[counter] = {}
        for function in function_data.keys():
            alias = function_data[function]["alias"]
            try:
                h = histograms[alias]
                t = process_time_histogram(h)
                histogram_data[counter][function] = t
            except KeyError:
                pass

    return histogram_data


if __name__ == "__main__":
    # Read function file
    data_folder = "../../data/"
    function_file = "extrae_functions.txt"
    function_file_path = join(data_folder, function_file)

    with open(function_file_path) as f:
        functions = [l.strip() for l in f]
    function_data = {}
    for function in functions:
        function_data[function] = {}

    # Read pcf file to find the names used in the histogram
    pcf_file = "trace_48.pcf"
    pcf_file_path = join(data_folder, pcf_file)
    with open(pcf_file_path) as f:
        csv_data = [l.strip() for l in f]
        started = False
        ended = False
        for line in csv_data:
            if started and not ended:
                split_line = line.split()
                if len(split_line) in [0, 1]:
                    continue
                elif len(split_line) == 2:
                    function_name = split_line[1]
                    alias = function_name
                elif len(split_line) == 3:
                    function_name = split_line[2]
                    alias = split_line[1]
                    function_name = function_name[1:-1]
                try:
                    function_data[function_name]["id"] = split_line[0]
                    function_data[function_name]["alias"] = alias
                except KeyError:
                    pass
                if not line.strip():
                    ended = True
            elif not started and line.count("60000019"):
                started = True

    # Dictionary to recover the original time from the alias
    alias_to_function_name = {}
    for key, value in function_data.items():
        try:
            alias_to_function_name[value["alias"]] = key
        except KeyError:
            pass

    # Read the histogram
    histogram_file = "histogram_48.txt"
    histogram_file_path = join(data_folder, histogram_file)
    with open(histogram_file_path) as f:
        data = f.read()
        csv_data = [l for l in data]

    histogram_info = process_category_histogram(data)

    # Save the index for each function
    for index, fun in enumerate(histogram_info["names"]):
        try:
            function_data[alias_to_function_name[fun]]["index"] = index
        except KeyError:
            pass
    # Clean non-appearing functions from dictionary
    functions_to_remove = []
    for function in function_data.keys():
        try:
            function_data[function]["index"]
        except KeyError:
            functions_to_remove.append(function)

    for function in functions_to_remove:
        del function_data[function]

    # Store time info in functions_data dictionary
    for key in function_data.keys():
        # Check if the function has an index associated
        function_data[key]["times"] = {}
        for label in paramedir_labels:
            function_time = histogram_info[label][function_data[key]["index"]]
            function_data[key]["times"][label] = function_time

    # Sort by average
    function_data = {k: v for k, v in sorted(
        function_data.items(), key=lambda item: item[1]["times"]["Average"])}

    # Compute totals
    totals = {}
    for label in paramedir_labels:
        totals[label] = sum([function_data[function]["times"][label]
                            for function in function_data.keys()])

    cases = (
        48,
        96,
        192,
    )
    histogram_files = {}
    for case in cases:
        histogram_files[case] = {}
        histogram_files[case]["instructions"] = "trace_%i_Instructions_by_function" % case
        histogram_files[case]["cycles"] = "trace_%i_Cycles_by_function" % case

    histogram_data = {}
    for key in histogram_files.keys():
        histogram_data[key] = compute_histogram_data(histogram_files[key])

    import matplotlib.pyplot as plt

    cases = list(histogram_files.keys())

    number_of_functions_to_print = 10
    counter = 0

    for function in reversed(list(function_data.keys())):
        print(function)
        xs = []
        ys = []
        for case in cases:
            try:
                instructions = histogram_data[case]["instructions"][function]["Average"] / 10. ** 6
                cycles = histogram_data[case]["cycles"][function]["Average"] / 10. ** 6
                instructions_per_cycle = instructions / cycles
                xs.append(cycles / 100.)
                ys.append(instructions_per_cycle)
                # print("Case: %i INS: %.1e  CYC: %.1e  IPC:  %.2f" % (case, instructions, cycles, instructions_per_cycle))
            except KeyError:
                print("Function %s in case %i not found!" % (function, case))
                pass

        if len(xs) != 3:
            continue
        for i in range(len(xs) - 1):
            plt.arrow(xs[i], ys[i], xs[i + 1] - xs[i],
                      ys[i + 1] - ys[i], alpha=.25, width=.001)
        plt.scatter(xs, ys, alpha=.5)
        counter += 1
        if counter >= number_of_functions_to_print:
            break
        # plt.text(xs[0], ys[0],function,size=5)

    plt.xlabel("Cycles (x10^8)")
    plt.ylabel("IPC")
    plt.show()
