source cfg/environment.env
export PYTHONPATH=$PYTHONPATH:$(pwd)
ssh_id=`echo ${SSH_CONNECTION} | awk '{print $2}'`
touch .${ssh_id}.env_loaded
trap 'rm .'${ssh_id}'.env_loaded' EXIT
python cfg/target/ConvertParamFile.py -p param.cfg  -o cfg/target/param_bash.cfg
