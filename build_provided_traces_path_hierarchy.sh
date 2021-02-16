#!/bin/bash

ssh_id=$(echo ${SSH_CONNECTION} | awk '{print $2}')
if [ ! -f .${ssh_id}.env_loaded ]; then
    echo "Please load the environment sourcing load_env.sh file"
    exit 1
fi


#if [ $# -ne 1  ]; then

#fi
