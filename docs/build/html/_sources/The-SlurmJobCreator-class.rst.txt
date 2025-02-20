
The SlurmJobCreator
~~~~~~~~~~~~~~~~~~~

It is a really simple python class that through a series of input arguments creates a file, that can be later submitted.

Let's take a look at the input arguments:

.. code-block:: python

       parser.add_argument("-f", "--file-name", default=None,
                           help="Name of the job you want to create or modify")
       parser.add_argument("--set-time", default=None, type=int,
                           help="Set slurm time, in minutes")
       parser.add_argument("--set-time-seconds", default=None, type=int,
                           help="Set slurm time, in minutes")
       parser.add_argument("--set-core", default=1, type=int,
                           help="Set number of cores to be used for the job")
       parser.add_argument("--set-core-per-node", default=48, type=int,
                           help="Set number of cores to be used for the job")
       parser.add_argument("-j", "--job-name", default=None,
                           help="Name of the job you want to create or modify")
       parser.add_argument("--set-queue", default="debug",
                           help="Set the queue name")
       parser.add_argument("-w", "--set-workload",
                           default=None, nargs='+',
                           help="list of commands that will be executed in the script")

The following parameter are taken as input 


* The first one is, of course, the name of the file: a .slurm extension will be added to the name, if not already present. **This argument is mandatory**
* The slurm time can be specified in minutes, or seconds. This last option is needed in case that, for example, you are using this script in a loop where the N of cores changes. Computing the final time as a multiplication btw N of cores and minutes can bring to a too high number, and bash loops does not allow decimal values. Specifying the time in seconds allows you to specify small amount of work per core let's say.
* The number of cores, and the number of cores per node: the default is 1 node, with 48 cores per node.
* The job name
* The queue: the dafault is debug, which is of course **HPC specific**
* The workload, i.e. what will actually be executed in the job

This last deserve an explication: in fact, it is not supposed to be used at the same time as the others. Look at the example

.. code-block:: bash

   python cfg/slurm/SlurmJobCreator.py --file-name test.slurm \
                                       --set-time-seconds $(( ${n_cores} * 8 )) \
                                       --job-name test_${n_cores}

   python cfg/slurm/SlurmJobCreator.py --file-name test.slurm --set-workload echo "First test"
   python cfg/slurm/SlurmJobCreator.py --file-name test.slurm --set-workload path/to/the/bash/script all the args
   sbatch --wait . test.slurm

The script is called more than once: first it needs to write down the slurm parameter. The following calls just add lines after the header of the file.
It means that you can add as many bash instructions as you need. The path to scripts and input args (if files) will be converted in absolute path, so if you move the script it will continue working.

Other queue system
##################

This script can easily be converted to work with PBS, for example: the only thing needed is to


* add an option to chose the queuing system
* 
  depending on the system chosen change the _write_header function, that for the moment sticks to slurm

  .. code-block:: python

        def __write_header(self):
           self.header.append("#SBATCH --ntasks " + str(self.cores) + "\n")
           if self.cores_per_node is not None:
               self.header.append("#SBATCH --ntasks-per-node " + str(self.cores_per_node) + "\n")
           self.header.append("#SBATCH --time " + str(self.time) + "\n")
           self.header.append("#SBATCH -J " + self.name + "\n")
           self.header.append("#SBATCH --qos=" + self.queue_name + "\n")

  If you create one header with PBS instruction everything should work.
