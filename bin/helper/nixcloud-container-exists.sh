#!/bin/sh
set -e
#tests if a container name is already in use
if [ $# -le 1 ]
  then
    echo "No container name specified "
    exit 1
fi
NAME=$1
#check if container already exists
if ! [ -n "$(lxc-ls --line | grep ^${NAME}\$)" ]; then
  echo "container with name ${NAME} does not exist."
  exit 1
fi
echo "container with name ${NAME} does exist."
exit 0
