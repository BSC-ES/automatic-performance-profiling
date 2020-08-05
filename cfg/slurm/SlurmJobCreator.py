from os.path import abspath, exists


def check_workload(workload):
    if exists(workload):
        return abspath(workload)
    else:
        return workload


class SlurmJob:
    def __init__(self, _file_name,
                 _cores=None, _cores_per_node=None,
                 _job_name=None,
                 _time=10,
                 _queue_name=None,
                 skip_header=False):
        # Name that will be used for the latex doc, without path
        self.file_name = _file_name if _file_name.count(".slurm") else _file_name + ".slurm"
        self.cores = _cores
        self.cores_per_node = _cores_per_node
        self.name = _job_name
        self.time = _time
        self.queue_name = _queue_name
        self.header = ["#!/bin/bash \n",
                       "############################################################################### \n",
                       "#SBATCH --output log_%j.out \n#SBATCH --error  log_%j.err \n"]
        if not skip_header:
          if self.time > 120 or self.cores > 768:
              self.queue_name = "bsc_es"
          self.__write_header()

    def __write_header(self):
        self.header.append("#SBATCH --ntasks " + str(self.cores) + "\n")
        if self.cores_per_node is not None:
            self.header.append("#SBATCH --ntasks-per-node " + str(self.cores_per_node) + "\n")
        self.header.append("#SBATCH --time " + str(self.time) + "\n")
        self.header.append("#SBATCH -J " + self.name + "\n")
        self.header.append("#SBATCH --qos=" + self.queue_name + "\n")

    def header_save(self):
        with open(self.file_name, "w") as slurm_job:
            for line in self.header:
                slurm_job.write(line)

    def append_workload(self, workload):

        with open(self.file_name, "a") as slurm_job:
            slurm_job.write("\n")
            for work in workload:
                # If command is a script, gives back the abs path
                work = check_workload(work)
                slurm_job.write(work + " ")


def get_command_line_arguments():
    """
    Returns a list of files that have been provided as a command line argument
    :return: list of files
    """

    # Parse and assert command line options
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("-f", "--file-name", default=None,
                        help="Name of the job you want to create or modify")
    parser.add_argument("--set-time", default=None, type=int,
                        help="Set slurm time, in minutes")
    parser.add_argument("--set-time-seconds", default=None, type=int,
                        help="Set slurm time, in minutes")
    parser.add_argument("--set-core", default=1, type=int,
                        help="Set number of cores to be used for the jon")
    parser.add_argument("--set-core-per-node", default=48, type=int,
                        help="Set number of cores to be used for the jon")
    parser.add_argument("-j", "--job-name", default=None,
                        help="Name of the job you want to create or modify")
    parser.add_argument("--set-queue", default="debug",
                        help="Set the queue name")
    parser.add_argument("-w", "--set-workload",
                        default=None, nargs='+',
                        help="list of commands that will be executed in the script")

    args = parser.parse_args()
    if args.set_time_seconds is not None:
        if args.set_time is None:
            # Covert time ensuring to request at least 1 min.
            args.set_time = int(args.set_time_seconds/60.) + 1
        else:
            parser.error("Just one time unity can be specified")
    if args.file_name is None:
        parser.error("The job filename has not been specified")
    return args


if __name__ == "__main__":
    # Get files from command line
    args = get_command_line_arguments()

    file_name = args.file_name
    time = args.set_time
    core = args.set_core
    job_name = args.job_name
    core_per_node = args.set_core_per_node
    queue = args.set_queue
    workload = args.set_workload

    if workload is None:
        slurm_job = SlurmJob(_file_name=file_name,
                             _time=time,
                             _cores=core, _cores_per_node=core_per_node,
                             _job_name=job_name,
                             _queue_name=queue)
        slurm_job.header_save()
    else:
        slurm_job = SlurmJob(file_name, skip_header=True)
        slurm_job.append_workload(workload)
