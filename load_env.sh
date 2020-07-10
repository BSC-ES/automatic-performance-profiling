source cfg/environment.env
export PYTHONPATH=$PYTHONPATH:$(pwd)
cd ${PATH_TO_MAGICCUT}
source add_to_path
cd - > /dev/null
touch .env_loaded
trap 'rm .env_loaded' EXIT
