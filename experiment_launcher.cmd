# Script to control a multiexperiment

experiments_folder=experiments
experiment_configurations_folder=experiments_to_run

# Create experiments folder if it does not exist
[ ! -d experiments ] && mkdir ${experiments_folder}

# Look at the experiments that need to be launched
experiment_configurations=$( ls ${experiment_configurations_folder} )

# For each experiment clone the repo there
for experiment in ${experiment_configurations} ; do
   # Clone repository to the new experiment folder
   git clone . ${experiments_folder}/${experiment}
   # Copy the configuration file into the new folder
   cp ${experiment_configurations_folder}/${experiment} ${experiments_folder}/${experiment}/param.cfg
   # Launch the experiment in background and save the log
   cd ${experiments_folder}/${experiment}
   nohup make experiment &> log &
   cd -
done
