import pickle
from os.path import isfile, isdir, abspath, exists
from os import listdir, makedirs, mkdir
import errno
from PIL import Image
import urllib.request
import io
import csv
import warnings
from glob import glob
import re

from cfg.latex.csv_formatter import converter


def report_load(report_name):
    if not report_name.count(".pkl"):
        report_name = report_name + ".pkl"
    try:
        pkl_obj = pickle.load(open(report_name, "rb"))
        # Update the path, in case the file has been moved
        pkl_obj.obj_name = report_name
        # Update the name, in case the file has been renamed
        pkl_obj.name = report_name.split("/")[-1].replace(".pkl", "")
        try:
            isinstance(pkl_obj, Report)
        except AssertionError:
            raise AssertionError("The loaded object has not been created with this version of the geneator. \n"
                                 " Please delete it and run again.")

    except IOError:
        print("No info, a new report will be created")
        pkl_obj = Report(report_name)
    return pkl_obj


def get_files_from_path(file_path, extension=None):
    # Manage input parameter passed with the nargs='+' option set
    if isinstance(file_path,list):
        # A folder or a file has been passed
        if len(file_path):
            file_path = file_path[0]
        elif len(file_path) == 0:
            raise AttributeError("The path %s is empty", file_path)
        # A list of files have been passed
        else:
            return file_path

    # If a wildcard has been passed as input
    if file_path.count("*"):
        return glob(file_path)
    try:
        # Single image
        assert isfile(file_path)
        return [file_path]
        # A folder have been passed
    except AssertionError:
        try:
            assert isdir(file_path)
            # This way order of the files will be the same on every platform
            files = [file_path + "/" + f for f in sorted(listdir(file_path))]
            # Stores the absolute path
            files = [abspath(f) for f in files]
            # Filters out other file's type
            if extension is not None:
                files = [f for f in files if f.count(extension)]
            return files
        except AssertionError:
            if exists(file_path):
                raise AssertionError("Could not determine nature of parameter %s", file_path)
            else:
                raise AssertionError("File %s does not exist", file_path)


class LatexText:
    def __init__(self):
        self.text = ""

    def add_text(self, txt):
        self.text = self.text + txt
        self.new_line()

    def new_line(self):
        self.text = self.text + "\n"

    def clearpage(self):
        self.add_text("\clearpage")

    def add_section2tex(self, section):
        self.clearpage()
        self.add_text("\section{" + section.section_title.replace("_", "\_") + "}")
        # self.clearpage()
        if section.text is not None:
            self.add_text(section.text)

    def add_subsection2tex(self, subsection):
        # self.clearpage()
        self.add_text("\subsection{" + subsection.subsection_title.replace("_", "\_") + "}")
        # self.clearpage()
        if subsection.text is not None:
            self.add_text(subsection.text)

    def add_image2tex(self, image, absolute_path):
        try:
            isinstance(image, ImgFile)
        except AssertionError:
            raise AssertionError("Error with %s: is this an image?", image)
        # Update path
        image.store_path = image.store_path
        # Create img dir if it doesn't exist
        makedirs(absolute_path + image.store_path, exist_ok=True)
        image.dump2disk(absolute_path)
        self.new_line()
        self.add_text("\\begin{figure}[H]")
        self.add_text("\includegraphics[width=\linewidth]{" + image.store_path + "/" + image.name + "}")
        self.add_text("\caption{" + image.caption + "}")
        self.add_text("\label{" + image.label + "}")
        self.add_text("\end{figure}")
        self.new_line()

    def add_csv2tex(self, csv_file, absolute_path):
        try:
            isinstance(csv_file, CsvFile)
        except AssertionError:
            raise AssertionError("Error with %s: is this an csv?", csv_file)
        # Update path
        csv_file.store_path = csv_file.store_path
        # Create img dir if it doesn't exist
        makedirs(absolute_path + csv_file.store_path, exist_ok=True)
        csv_file.dump2disk(absolute_path)
        self.new_line()
        self.add_text("\\begin{table}[H]")
        self.add_text("\centering")
        self.add_text("\csvautobooktabular{" + csv_file.store_path + "/" + csv_file.name + "}")
        self.add_text("\caption{" + csv_file.caption + "}")
        self.add_text("\end{table}")
        self.new_line()


class Section:
    def __init__(self, _title):
        self.section_title = _title
        self.section_name = self.section_title.lower().replace(" ", "_")
        self.section_number = 0
        self.subsections = []
        self.images = []
        self.csv_files = []
        self.text = None

    def add_image(self, file_path, subsection_name=None, caption=None):
        images = get_files_from_path(file_path, ".png")
        for img in images:
            if caption is not None:
                try:
                    assert (isfile(caption))
                    with open(caption, 'r') as img_caption:
                        actual_caption = img_caption.readlines()
                    caption = actual_caption[0].replace("\n", "")
                except AssertionError:
                    if caption.count(".txt"):
                        AssertionError("File %s not found", caption)
                    else:
                        pass
            img_obj = ImgFile(img, self.section_name, subsection_name, caption)
            # Avoid adding item more than once ... useful in case of make target's failure
            for s_img in self.images:
                if img_obj.path == s_img.path:
                    warnings.warn("Image " + img_obj.path + " already present", stacklevel=4)
                    return
            # Save the actual picture in the img_obj
            img_obj.store()
            self.images.append(img_obj)

    def add_csv(self, file_path, subsection_name=None, csv_convert=False, csv_purge=False, silent_mode=False):
        try:
            csv_files = get_files_from_path(file_path, ".csv")
        except AssertionError:
            if silent_mode:
                return
            else:
                raise AssertionError()
        for csv_file in csv_files:
            csv_obj = CsvFile(csv_file,
                              self.section_name,
                              subsection_name,
                              csv_purge,
                              csv_convert)
            # Avoid adding item more than once ... useful in case of make target's failure
            for s_csv in self.csv_files:
                if csv_obj.path == s_csv.path:
                    warnings.warn("File " + csv_obj.path + " already present", stacklevel=4)
                    return
            self.csv_files.append(csv_obj)

    # Some text, produced by some python script in csv format will be added to the report
    def add_text_as_csv(self, csv_format_text, subsection_name=None, computed_quantity=None):
        csv_obj = CsvFile(self.subsection_title, _section=self.section_name, _subsection=subsection_name,
                          _caption=computed_quantity)
        # Save the data in the csv_obj
        csv_obj.store(csv_format_text)
        # Add to report obj
        self.csv_files.append(csv_obj)

    def get_subsection(self, subsection_title):
        for subsection in self.subsections:
            if subsection_title == subsection.subsection_title:
                return subsection
        return None

    def add_subsection(self, subsection_title):
        subsection = Subsection(self.section_title, subsection_title)
        self.subsections.append(subsection)

    # Save into a variable the text we will put into the section
    def add_text(self, section_text):
        try:
            assert isfile(section_text)
        except AssertionError:
            raise AssertionError("File %s is not a text file", section_text)
        with open(section_text, 'r') as section_text_file:
            self.text = section_text_file.read()


class Subsection(Section):
    def __init__(self, _section_title, _subsect_title):
        super(Subsection, self).__init__(_section_title)
        self.subsection_title = _subsect_title
        self.subsection_name = self.subsection_title.lower().replace(" ", "_")
        self.subsection_number = 0

    # Overwrites method adding images subsection info
    def add_image(self, file_path, caption=None):
        super(Subsection, self).add_image(file_path, subsection_name=self.subsection_name, caption=None, )

    # Overwrites method adding csv subsection info
    def add_csv(self, file_path, csv_convert, csv_purge, silent_mode):
        super(Subsection, self).add_csv(file_path, self.subsection_name, csv_convert, csv_purge, silent_mode)

    # Overwrites method adding csv subsection info
    def add_text_as_csv(self, csv_format_text, computed_quantity):
        super(Subsection, self).add_text_as_csv(csv_format_text, self.subsection_name, computed_quantity)


class ImgFile:
    def __init__(self, _path, _section, _subsection=None, _caption=None):
        self.path = _path
        self.store_path = None
        self.name = self.path.split("/")[-1]
        self.extension = self.name.split(".")[-1]
        self.label = "fig:" + self.name.replace(self.extension, "")
        self.caption = _caption
        self.pic = None
        self.section = _section
        self.subsection = _subsection

        if self.caption is not None:
            # Check if newcommands has been used, and convert to camelcase
            if self.caption.count("${"):
                pattern="\${[A-zA-z_]+}"
                for word in self.caption.split():
                    if re.search(pattern, word):
                        newcommand = word.replace("${", "\\")
                        newcommand = newcommand.replace("}", "")
                        newcommand = "".join([nc.capitalize() for nc in newcommand.split("_")])
                        self.caption = self.caption.replace(word, newcommand)
        else:
            self.caption = self.label.replace("_", " ").replace("fig:", "")

    # Stores the image in an obj
    def store(self):
        with open(self.path, "rb") as img:
            self.pic = io.BytesIO(img.read())

        # Path where the img will be saved
        self.store_path = "image/" + self.section
        if self.subsection is not None:
            self.store_path = self.store_path + "/" + self.subsection

    # Dumps the image to  the location specified in path
    def dump2disk(self, absolute_path):
        im = Image.open(self.pic)
        im.save(absolute_path + self.store_path + "/" + self.name)


class CsvFile:
    def __init__(self, _path, _section_name, _subsection_name, _purge=False, _convert=False, _caption=None):
        self.path = _path
        self.store_path = None
        self.name = self.path.split("/")[-1]
        self.label = "tab:" + self.name.replace(".csv", "")
        self.caption = self.label.replace("_", "\\_").replace("tab:", "") if _caption is None else _caption
        self.csv_data = None
        self.section = _section_name
        self.subsection = _subsection_name
        self.store(csv_convert=_convert, csv_purge=_purge)

    def purge_csv_data(self):
        n_col = len(self.csv_data[0])
        n_row = len(self.csv_data[1:])

        # Reverse otherwise removing data will end in an out of range error
        for col in reversed(range(n_col)):
            try:
                col_val = [int(data[col]) for data in self.csv_data[1:]]
                check_list = [0] * n_row
            except ValueError:
                try:
                    col_val = [float(data[col]) for data in self.csv_data[1:]]
                    check_list = [0.0] * n_row
                except ValueError:
                    continue
            if col_val == check_list:
                # Now we want to remove entries also from the header
                for row in range(n_row + 1):
                    self.csv_data[row].remove(self.csv_data[row][col])

    def store(self, text=None, csv_convert=False, csv_purge=False):
        if text is None:
            if csv_convert:
                self.csv_data = converter(self.path, summary=True)
            else:
                with open(self.path, newline='') as csv_file:
                    self.csv_data = list(csv.reader(csv_file))
                    # Remove rows if they're empty
                    self.csv_data = [d for d in self.csv_data if d != []]
            # If specified, remove empty columns from csv file
            if csv_purge:
                self.purge_csv_data()
        else:
            self.csv_data = text

        # Path where the file data will be dumped
        self.store_path = "csv/" + self.section
        if self.subsection is not None:
            self.store_path = self.store_path + "/" + self.subsection

    def purge_csv_data(self):
        n_col = len(self.csv_data[0])
        n_row = len(self.csv_data[1:])

        # Reverse otherwise removing data will end in an out of range error
        for col in reversed(range(n_col)):
            try:
                col_val = [int(data[col]) for data in self.csv_data[1:]]
                check_list = [0] * n_row
            except ValueError:
                try:
                    col_val = [float(data[col]) for data in self.csv_data[1:]]
                    check_list = [0.0] * n_row
                except ValueError:
                    continue
            if col_val == check_list:
                # Now we want to remove entries also from the header
                for row in range(n_row + 1):
                    self.csv_data[row].remove(self.csv_data[row][col])

    # Writes csv data to file
    def dump2disk(self, absolute_path):
        if exists(absolute_path + self.store_path + "/" + self.name):
            import hashlib
            hash_name = hashlib.sha256(self.path.encode("utf8")).hexdigest()
            self.name = hash_name + "_" + self.name
        with open(absolute_path + self.store_path + "/" + self.name, 'wt') as f_output:
            csv_output = csv.writer(f_output)
            for data_row in self.csv_data:
                data_row = [dr.replace("_", "") for dr in data_row]
                csv_output.writerow(data_row)


class Report:
    def __init__(self, _name):
        # Name that will be used for the latex doc, without path
        self.name = _name.replace(".pkl", "").split("/")[-1]
        self.absolute_path = None
        self.obj_name = _name
        self.sections = []
        self.total_section_number = 0
        self.title = ""
        self.authors = []
        self.newcommand = {}
        self.newcommand_file = "newcommand_file.tex"
        self.bsc_logo_url = 'https://pbs.twimg.com/profile_images/378800000692705583/015be2057821ebe8382c21804a8504fc_400x400.png'
        self.preamble = "\documentclass[11pt,a4paper,oldfontcommands]{article} \n" \
                        "\maxdeadcycles=2000 \n" \
                        "\\usepackage{graphicx} \n" \
                        "\\usepackage{csvsimple} \n" \
                        "\\usepackage{booktabs}\n" \
                        "\\usepackage{hyperref}\n" \
                        "\\usepackage{float}\n" \
                        "\input{" + self.newcommand_file + "}\n" \
                                                           "\\title{TITLE} \n " \
                                                           "\\author{AUTHORS} \n  \date{\\today} \n" \
                                                           "\makeatletter \n" \
                                                           "\def\@maketitle{ \n" \
                                                           "\\begin{center} \n" \
                                                           "{\Huge \\bfseries \sffamily \@title }\\\\[4ex] \n" \
                                                           "{\Large  \@author}\\\\[4ex] \n" \
                                                           "\@date\\\\[8ex] \n" \
                                                           "\includegraphics[width = 40mm]{LOGO} \n" \
                                                           "\end{center}} \n" \
                                                           "\makeatother \n"

        self.text = None

    def add_title(self, title):
        self.title = title

    def add_authors(self, authors):
        self.authors.append(authors)

    def __set_absolute_path(self):
        # Update patterns
        absolute_path = abspath(self.obj_name).rsplit("/", 1)[0] + "/"
        self.absolute_path = absolute_path

    def __set_title(self):
        if not len(self.title):
            print("Report's title has not been specified")
        else:
            self.preamble = self.preamble.replace("TITLE", self.title)

    def __set_authors(self):
        if not len(self.authors):
            print("Report's authors have not been specified")
        else:
            self.preamble = self.preamble.replace("AUTHORS", ", ".join(self.authors))

    def __set_logo(self):
        abs_logo_path = self.image_folder + "/BSC_Logo.png"
        rel_logo_path = "image/BSC_Logo.png"
        self.preamble = self.preamble.replace("LOGO", rel_logo_path)
        with urllib.request.urlopen(self.bsc_logo_url) as img:
            img_logo = io.BytesIO(img.read())
            im = Image.open(img_logo)
            im.save(abs_logo_path)

    def __begin_doc(self):
        self.image_folder = self.absolute_path + "/image"
        self.csf_folder = self.absolute_path + "/csv"
        self.name = self.absolute_path + self.name
        # Create root folder for images and csv
        try:
            mkdir(self.absolute_path + "/image")
            mkdir(self.absolute_path + "/csv")
        except OSError as exc:
            if exc.errno != errno.EEXIST:
                raise
            pass

        # Add bsc logo to the report
        self.__set_logo()
        # Crete latex text object
        report_text = LatexText()
        report_text.add_text(self.preamble)
        report_text.add_text("\\begin {document}")
        report_text.add_text("\maketitle")
        report_text.clearpage()
        report_text.add_text("\\tableofcontents")
        report_text.clearpage()
        self.text = report_text

    def __end_doc(self):
        try:
            isinstance(self.text, LatexText)
        except AssertionError:
            raise AssertionError("something went wrong trying to close the report")
        self.text.add_text("\end{document}")

    def __create_newcommand_file(self):
        f_ncf = open(self.absolute_path + "/" + self.newcommand_file, "w")
        for key, value in self.newcommand.items():
            clean_key = "".join([k.capitalize() for k in key.split("_")])
            f_ncf.write("\\newcommand\\" + clean_key + "{" + value + "}\n")
        f_ncf.close()

    def write_to_txt(self):
        # Set first page
        self.__set_authors()
        self.__set_title()

        # Define where to create report
        self.__set_absolute_path()

        # Now that absolute path has been set we can start dumping to disk
        self.__create_newcommand_file()

        # Initialize text member of the class and add preamble
        self.__begin_doc()

        for section in self.sections:
            self.text.add_section2tex(section)
            for image in section.images:
                self.text.add_image2tex(image, self.absolute_path)
            for n, csv_file in enumerate(section.csv_files):
                if not n % 4 and not n == 0:
                    self.text.clearpage()
                self.text.add_csv2tex(csv_file, self.absolute_path)

            for subsection in section.subsections:
                self.text.add_subsection2tex(subsection)
                for image in subsection.images:
                    self.text.add_image2tex(image, self.absolute_path)
                for csv_file in subsection.csv_files:
                    self.text.add_csv2tex(csv_file, self.absolute_path)

        self.__end_doc()

        file_name = self.name + ".tex"
        report_file = open(file_name, "w")
        # Actually writes the text to file
        report_file.write(self.text.text)
        report_file.close()
        return file_name

    def get_section(self, section_title):
        if self.sections is not None:
            for section in self.sections:
                if section_title == section.section_title:
                    return section
        return None

    def add_section(self, new_section_title, new_section_number=0):
        # Creates a new obj Section
        new_section = Section(new_section_title)
        # Number the new section
        new_section.section_number if new_section_number != 0 else self.total_section_number
        self.sections.append(new_section)
        # Increment the number of total sections
        self.total_section_number = self.total_section_number + 1

    def add_newcommand(self, newcommand_file):
        f = open(newcommand_file, "r")
        params = [l.replace("\n", "") for l in f if l.count("#") == 0 and l != "\n"]

        for p in params:
            key, val = p.split("=")
            self.newcommand[key.strip()] = val.strip()

    def get_context(self, section_title, section_number=0, subsection_title=None):
        section = self.get_section(section_title)
        # Check if section exists
        if section is not None:
            # See if a subsection was specified
            if subsection_title is not None:
                # Check if subsection exists
                subsection = section.get_subsection(subsection_title)
                if subsection is not None:
                    return subsection
                # If it doesn't, create one
                else:
                    section.add_subsection(subsection_title)
                    try:
                        # Return subsection handler
                        return self.get_context(section_title, section_number, subsection_title)
                    except RecursionError:
                        raise RecursionError("In searching for subsection %s of section %s", subsection_title,
                                             section_title)
            return section
        # If it doesn't, create one
        else:
            self.add_section(section_title, section_number)
            try:
                # Return the section handler
                return self.get_context(section_title, subsection_title=subsection_title)
            except RecursionError:
                raise RecursionError("In searching for section %s", section_title)

    def save(self):
        pickle.dump(self, open(self.obj_name, "wb"))
        print("Content dumped to ", self.obj_name)

    def inspect(self):
        print("Contents of pkl object:", self.name)
        for s in self.sections:
            print("Section:", s.section_title)
            for s_img in s.images:
                print("  --image", s_img.path)
            for s_csv in s.csv_files:
                print("  --csv: ", s_csv.path)
            for ss in s.subsections:
                print("    --Subsection:", ss.subsection_title)
                for ss_img in ss.images:
                    print("      --image:", ss_img.path)
                for ss_csv in ss.csv_files:
                    print("      --csv:", ss_csv.path)


def get_command_line_arguments():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """

    # Parse and assert command line options
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("-O", "--report-obj", default=None,
                        help="Name of the object that will progressively store report information")
    parser.add_argument("-t", "--report-title",
                        type=str, default=None,
                        help="Title that will appear in the Report")
    parser.add_argument("-A", "--report-authors",
                        type=str, default=None,
                        help="These will appear as report authors")
    parser.add_argument("-n", "--section-number",
                        type=int, default=None,
                        help="name of the section that will be added if doesn't exist")
    parser.add_argument("-S", "--section-title",
                        type=str, default=None,
                        help="title of the section that will be added if doesn't exist")
    parser.add_argument("-s", "--subsection-title",
                        type=str, default=None,
                        help="title of the subsection that will be added if doesn't exist")
    parser.add_argument("-i", "--add-img",
                        default=None, nargs='+',
                        help="path to an image or to an image folder which will be added to the section")
    parser.add_argument("--add-img-caption",
                        type=str, default=None,
                        help="If and image has been added, the caption can be specified either a string or a file")
    parser.add_argument("-c", "--add-csv", default=None,
                        help="path to a csv or a folder of csv that will be added to the section")
    parser.add_argument("--csv-convert",
                        default=False, action="store_true",
                        help="If the file is a paraver file and need conversion to csv")
    parser.add_argument("-p", "--csv-purge",
                        default=False, action="store_true",
                        help="Eliminates empty columns")
    parser.add_argument("-T", "--text-file", default=None,
                        help="path to a latex text file which will be used as section or subsection text")
    parser.add_argument("-d", "--dump-to-file",
                        default=False, action="store_true",
                        help="Triggers the generation of a tex file to be compiled with all the data stored so far")
    parser.add_argument("-I", "--inspect",
                        default=False, action="store_true",
                        help="Print to screen content of pkl obj")
    parser.add_argument("--silent", action="store_true",
                        help="Ignore if added file doesn't exist")
    parser.add_argument("--add-newcommand",
                        default=None,
                        help="File which contains variable definitions that can be used in Fig. or Tab captions")
    args = parser.parse_args()
    if not args.report_obj:
        parser.error("A name for the object must be given")
    if args.add_csv is not None and args.section_title is None:
        parser.error("A name for the section must be given")
    if args.add_img is not None and args.section_title is None:
        parser.error("A name for the section must be given")
    if args.csv_convert or args.csv_purge:
        if not args.add_csv:
            parser.error("Purge and convert flags must be used with csv files")
    if args.silent:
        if not args.add_csv and not args.add_img:
            parser.error("Silent mode can be run just when adding items to pkl object")
    if args.add_img_caption and not args.add_img:
        parser.error("A caption cannot be added if an image has not been specified")
    if args.add_newcommand is not None:
        try:
            assert (isfile(args.add_newcommand))
        except AssertionError:
            parser.error("The parameter file specified for newcommands does not exist.")
    return args


if __name__ == "__main__":
    # Get files from command line
    args = get_command_line_arguments()

    report_obj = args.report_obj
    report_title = args.report_title
    report_author = args.report_authors
    section_title = args.section_title
    section_number = args.section_number
    subsection_title = args.subsection_title
    image = args.add_img
    img_caption = args.add_img_caption
    csv_file = args.add_csv
    csv_convert = args.csv_convert
    csv_purge = args.csv_purge
    dump_to_file = args.dump_to_file
    text_file = args.text_file
    inspect_pkl_obj = args.inspect
    silent_mode = args.silent
    newcommand_file = args.add_newcommand

    # Load a report if exist, create a new one in case it doesn't
    report = report_load(report_obj)

    # Just print object content
    if inspect_pkl_obj:
        report.inspect()
    else:
        if report_title is not None:
            report.add_title(report_title)
        if report_author is not None:
            report.add_authors(report_author)

        if newcommand_file is not None:
            report.add_newcommand(newcommand_file)

        # Some content has to be added to pkl object
        if section_title is not None:
            # Get the context
            context = report.get_context(section_title, section_number, subsection_title)
            # Append images
            if image is not None:
                context.add_image(image, caption=img_caption)
            # Append csv table
            if csv_file is not None:
                context.add_csv(csv_file, csv_convert=csv_convert, csv_purge=csv_purge, silent_mode=silent_mode)
            # Add text to section
            if text_file is not None:
                context.add_text(text_file)

            # Save the report obj

        report.save()
        # Writes to  file the loaded obj
        if dump_to_file:
            report_name = report.write_to_txt()
            print("Report generates successfully in", report_name)
