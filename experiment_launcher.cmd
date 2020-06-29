# Script to control a multiexperiment

experiments_folder=experiments
experiment_configurations_folder=$1

# Some sanity checks
if [ -z "$1" ] ; then
   echo "Argument required"
   exit 1
fi
if [ ! -d "$1" ] ; then 
   echo "Not a folder" 
   exit 1
fi

# Create experiments folder if it does not exist
[ ! -d experiments ] && mkdir ${experiments_folder}

# Look at the experiments that need to be launched
experiment_configurations=$( ls ${experiment_configurations_folder} )

# For each experiment clone the repo there
for experiment in ${experiment_configurations} ; do
   if [ -d ${experiments_folder}/${experiment} ] ; then
      continue
   fi
   # Clone repository to the new experiment folder
   git clone . ${experiments_folder}/${experiment}
   # Copy the configuration file into the new folder
   cp ${experiment_configurations_folder}/${experiment} ${experiments_folder}/${experiment}/param.cfg
   # Launch the experiment in background and save the log
   cd ${experiments_folder}/${experiment}
   nohup make experiment &> log &
   cd -
done
