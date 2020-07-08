# Script to control a multiexperiment
# Mandatory argument: folder with configurations
experiment_configurations_folder=$1
# Optional argument: name for the results folder
if [[ $# -eq 2 ]]
then
  experiments_folder=$2
# Default name is set
else
  # remove the last char if is a slash
  if [[ `echo ${experiment_configurations_folder:-1}`=="/" ]]
  then
    experiment_configurations_folder=${experiment_configurations_folder%?}
  fi
  # Gets the config folder name
  experiments_folder=${experiment_configurations_folder##*/}
fi

# Some sanity checks
if [ $# -eq 0  ] ; then
   echo "Argument required"
   exit 1
fi
# check folder exists
if [ ! -d "$1" ] ; then 
   echo "Not a folder" 
   exit 1
fi

# Create experiments folder if it does not exist
mkdir -p ${experiments_folder}

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
## BEGIN -- NOT TO PUSH TO MASTER 
#cd  ${experiments_folder}/${experiment}/cfg/parser/
#for file in ./*.py
#do
#  sed -i s/cfg.parser.//g $file
#done
#cd -
##  END -- NOT TO PUSH TO MASTER

