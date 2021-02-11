source cfg/env/MN4/environment.env
export PYTHONPATH=$PYTHONPATH:$(pwd)
ssh_id=`echo ${SSH_CONNECTION} | awk '{print $2}'`
touch .${ssh_id}.env_loaded
trap 'rm .'${ssh_id}'.env_loaded' EXIT
#python cfg/target/ConvertParamFile.py -p configurations/model/nemo/strongscaling/BENCH  -o cfg/target/param_bash.cfg
#python cfg/target/ConvertParamFile.py -p ${model_config_folder}/strongscaling/${configuration} -o cfg/target/param_bash.cfg
python cfg/target/ConvertParamFile.py -p param.cfg -o cfg/target/param_bash.cfg
