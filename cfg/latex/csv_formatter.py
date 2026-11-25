import csv

# List of different accumulated results given by paraver
#paraver_labels = ("Total",
#                  "Average",
#                  "Maximum",
#                  "Minimum",
#                  "StDev",
#                  "Avg/Max",
#                  )
paraver_labels = ("Average",
                  "Maximum",
                  "Minimum",
                  "StDev"
                  )

class ParaverFile:
    def __init__(self, _name):
        self.name = _name
        self.lines = self.get_lines()
        self.nthreads = self.get_nthreads()
        self.header = self.get_header()
        self.data_lines = self.get_data_lines()
        self.summary = self.get_summary()

    def remove_tab(self):
        self.lines = [l.replace('\t', ' ') for l in self.lines]

    def remove_spaces(self):
        self.lines = [l.replace(' ', '_') for l in self.lines]

    def get_header(self):
        header = self.lines[0]
        return header

    def get_lines(self):
        with open(self.name, 'rt') as f:
            self.lines = f.readlines()
            self.remove_spaces()
            self.remove_tab()
            self.lines = [l.split() for l in self.lines if len(l) > 0]
            # self.lines = [l[1:] for l in self.lines]
            return self.lines

    def get_data_lines(self):
        self.data_lines = []
        for l in self.lines:
            if len(l) > 0 and l[0].count("THREAD"):
                self.data_lines.append(l[1:])
        return self.data_lines

    def get_nthreads(self):
        self.nthreads = 0
        for line in self.lines:
            if len(line) > 0 and line[0].count("THREAD"):
                self.nthreads = self.nthreads + 1
        return self.nthreads

    def get_summary(self):
        summary = {}
        for line in self.lines:
            for field in line:
                if field in paraver_labels:
                    summary[field.lower()] = line[1:]
        return summary

    def print_csv(self, summary=False):
        # output_file = "new_file"
        # with open(output_file, 'wt') as f_output:
        #     csv_output = csv.writer(f_output)
        data_rows = []
        if summary:
            header = ["Statistic"] + [f"{field} (%)" for field in self.header]
            # data_rows.append(header)
            for key, val in self.summary.items():
                data_rows.append([key] + val)
        else:
            header = self.header
            # data_rows.append(self.header)
            for data in self.data_lines:
                data_rows.append(data[0])

        return [header] + data_rows


def converter(input_file, summary=False):
    file = ParaverFile(input_file)
    fmt_data = file.print_csv(summary)
    return fmt_data


def formatter(input_file, output_file):
    with open(input_file, 'rt') as f_input, open(output_file, 'wt') as f_output:
        csv_input = csv.reader(f_input)
        csv_output = csv.writer(f_output)
        # Write header
        csv_output.writerow(next(csv_input))

        for row in csv_input:
            for i_row in range(1, len(row[1:]) + 1):
                try:
                    row[i_row] = '{:.2f}'.format(float(row[i_row]))
                except ValueError:
                    continue
            csv_output.writerow(row)
