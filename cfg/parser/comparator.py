import os

from cfg.parser.utils.curation import multiexperiment_comparison, \
    weakscaling_compute
from cfg.parser.utils.parsers import TimingInformation
from cfg.parser.utils.curation import multiexperiment_scalability_plot

def parse_args():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """
    import argparse
    from cfg.Error import PathType
    parser = argparse.ArgumentParser()
    parser.add_argument("-j", "--json-files", nargs="*", type=PathType(exists=True, type="file"),
                        help="list of file or folder in which json files can be found")
    parser.add_argument("-w", "--weak-scaling", default=False, action="store_true",
                        help="Whether you want to compute weak scaling ")
    parser.add_argument("-s", "--sypd", default=False, action="store_true",
                        help="Whether you want to compare SYPD ")
    parser.add_argument("-f", "--function-info", default=False, action="store_true",
                        help="Whether you want to compare elapsed time by function ")
    parser.add_argument("--out-dir", default=None,
                        help="Folder where the results will be saved. The computed quantity will be added to the name")
    return parser.parse_args()


if __name__ == "__main__":

    # Get files from command line
    args = parse_args()
    json_file_list = args.json_files

    weak_scaling = args.weak_scaling
    SYPD = args.sypd
    function_info = args.function_info
    out_dir = args.out_dir

    # Load the two experiments provided.
    experiment_data = [TimingInformation(json_file=f) for f in json_file_list]

    comparator_id = ""
    for exp in experiment_data:
        comparator_id += exp.experiment_name + "-"

    if SYPD:
        # Example how to get comparison of SYPD

        multiexperiment_comparison(
            experiment_data, field1="ts_per_second").print(os.path.join(out_dir, comparator_id + "scaling.csv"))

        scalability_plot_fn = os.path.join(out_dir, comparator_id + "scaling.png")
        multiexperiment_scalability_plot(
            experiment_data, filename=scalability_plot_fn)

    # Prints weak scaling info
    if weak_scaling:
        weakscaling_compute(experiment_data, os.path.join(out_dir, comparator_id + "scaling.csv"))
