#!/bin/sh
#check for arguments
set -e
if [ $# -le 1 ]
  then
    echo "No container name and/or configurationFile specified "
    exit 0
fi

#init variables
NAME=$1
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIGURATION="$(realpath $2)"

LXCPATH="${ROOT_FS_HOME}/${NAME}"
ROOT_FS="${ROOT_FS_HOME}/${NAME}/rootfs"

IPGENERATED=false

#check if container already exists
if [ -n "$(lxc-ls --line | grep ^${NAME}\$)" ]; then
  echo "container with name ${NAME} already exists. use 'nixcloud-container update' instead."
  exit 1
fi

shift 2
getLxcNixParameter $@

#check if an ip needs to be generated
set +e
ipNotNeeded=$(nix-instantiate $NIXARGUMENTS --eval $SCRIPTDIR/hasIp.nix --arg config "import $CONFIGURATION")
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
workdir=$(pwd)
mkdir -p $ROOT_FS
mkdir -p $ROOT_FS/{proc,sys,dev,nix/store,etc,init}
chown 100000:100000 $ROOT_FS
chown -R 100000:100000 $ROOT_FS/*
chmod 0755 $ROOT_FS/etc
if ! [ -e $ROOT_FS/etc/os-release ]; then
  touch $ROOT_FS/etc/os-release
fi

#save config path
echo "${CONFIGURATION}" >> "${LXCPATH}/nixConfigPath"

#create init and container configuration inside the rootfs
set +e
profilePath="/nix/var/nix/profiles/nixcloud-container/${NAME}/profile"
mkdir -p /nix/var/nix/profiles/nixcloud-container/${NAME}
if [ "$ipNotNeeded" == "true" ]; then
  ip=$(nix-instantiate $NIXARGUMENTS --eval $SCRIPTDIR/getIp.nix --arg config "import $CONFIGURATION")
  setFixedIp $NAME $ip
  nix-env -i $NIXARGUMENTS -f $SCRIPTDIR/lxc-container.nix -p ${profilePath}  --argstr name "${NAME}" --arg container "import ${CONFIGURATION}"
  err=$?
else
  nix-env -i $NIXARGUMENTS -f $SCRIPTDIR/lxc-container.nix -p ${profilePath}  --argstr name "${NAME}" --arg container "import ${CONFIGURATION}" --argstr ip "10.101.$(($ip/256)).$(($ip%256))"
  err=$?
fi
if [ $err -ne 0 ]; then
  echo "could not evaluate container config"
  freeIp $NAME
  exit $err
fi
#create lxc container
lxc-create -n "${NAME}" -f "${profilePath}/configWrapper" -t none $LXCARGUMENTS
err=$?
if [ $err -ne 0 ]; then
  echo "could not create lxc container"
  freeIp $NAME
  exit $err
fi
echo "successfully created container ${NAME}"
