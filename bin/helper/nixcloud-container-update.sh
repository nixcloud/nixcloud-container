#!/bin/sh
set -e
#check for arguments
if [ $# -le 0 ]; then
  echo "No container name specified "
  exit 0
fi

declare NAME=$1
LXCPATH="${ROOT_FS_HOME}/${NAME}"
CONFIGURATIONPATH="${LXCPATH}/nixConfigPath"
if [ $# -le 1 ]; then
  CONFIGURATION=$(cat "${CONFIGURATIONPATH}")
  echo "No container config specified only updating using ${CONFIGURATIONPATH}."
else
  declare -r CONFIGURATION="$(realpath $2)"
  mkdir -p ${LXCPATH}
  touch "${CONFIGURATIONPATH}"
  echo "${CONFIGURATION}" >> "${CONFIGURATIONPATH}"
fi
#init constants
declare SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
declare ROOT_FS="${ROOT_FS_HOME}/${NAME}/rootfs"

#check if container already exists
set +e
status=$(lxc-ls --line | grep ^${NAME}\$)
echo $status
if [ "$status" == "" ]; then
  echo "WARNING: container with name ${NAME} does not exist. Container will be created."
  source $BASEDIR/helper/nixcloud-container-create.sh "${@}"
  exit 0
fi
set -e
shift 2
getLxcNixParameter $@

#check if an ip needs to be generated
set +e
declare -r ipNotNeeded=$(nix-instantiate $NIXARGUMENTS --eval $SCRIPTDIR/hasIp.nix --arg config "import $CONFIGURATION")
err=$?
set -e
if [ $err -ne 0 ]; then
  echo "could validate if an ip is given or needs to be generated."
  exit $err
fi
if [ "$ipNotNeeded" == "true" ]; then
  echo "container ip specified in configurationFile"
else
  getIp $NAME
  echo "Ip is 10.101.$(($ip/256)).$(($ip%256))"
fi

#create rootfs
if ! [ -d $ROOT_FS ]; then
  mkdir -p $ROOT_FS
  mkdir -p $ROOT_FS/{proc,sys,dev,nix/store,etc}
  chown 100000:100000 $ROOT_FS
  chown -R 100000:100000 $ROOT_FS/*
  chmod 0755 $ROOT_FS/etc
  if ! [ -e $ROOT_FS/etc/os-release ]; then
    touch $ROOT_FS/etc/os-release
  fi
fi

#create init and container configuration inside the rootfs
cd $ROOT_FS
set +e

#ResultNumber=$(ls -rt $ROOT_FS/result |tail -1)
#ResultNumber=$((ResultNumber + 1))
profilePath="/nix/var/nix/profiles/nixcloud-container/${NAME}/profile"
if [ "$ipNotNeeded" == "true" ]; then
#  nix-build $NIXARGUMENTS $SCRIPTDIR/lxc-container.nix -o $ROOT_FS/result/$ResultNumber --arg name "\"${NAME}\"" --arg container "import ${CONFIGURATION}"
  nix-env -i $NIXARGUMENTS -f $SCRIPTDIR/lxc-container.nix -p ${profilePath} --argstr name "${NAME}" --arg container "import ${CONFIGURATION}"
else
#  nix-build $NIXARGUMENTS $SCRIPTDIR/lxc-container.nix -o $ROOT_FS/result/$ResultNumber --arg name "\"${NAME}\"" --arg container "import ${CONFIGURATION}" --arg ip "\"10.101.$(($ip/256)).$(($ip%256))\""
  nix-env -i $NIXARGUMENTS -f $SCRIPTDIR/lxc-container.nix -p ${profilePath} --argstr name "${NAME}" --arg container "import ${CONFIGURATION}" --argstr ip "10.101.$(($ip/256)).$(($ip%256))"
fi
err=$?
if [ $err -ne 0 ]; then
  echo "could not evaluate container config"
  exit $err
fi

lxc-info -n "${NAME}" | grep "doesn't exist" &> /dev/null
if [ $? == 0 ]; then
  #create lxc container
  echo "WARNING: container did not exist, rebuilding container"
  lxc-create -n "${NAME}" -f $ROOT_FS/result/config -t none $LXCARGUMENTS
  exit $?
fi

updateContainer $NAME
