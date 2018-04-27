#!/bin/sh
set -e
NAME=$1
shift 1
#ROOT_FS="${ROOT_FS_HOME}/${NAME}/rootfs"
getLxcNixParameter $@
#echo "${ROOT_FS}"
#export CONTAINER_ROOT="${ROOT_FS}"
set +e
#lxc-start -n "${NAME}" -s "lxc.rootfs=${ROOT_FS}" /result/container/init $LXCARGUMENTS
#ResultNumber=$(ls -rt $ROOT_FS/result |tail -1)
#lxc-start -n "${NAME}" "/result/container/init" $LXCARGUMENTS
lxc-start -n "${NAME}" $LXCARGUMENTS
err=$?
if [ $err -ne 0 ]; then
  echo "could not start container"
  exit $err
fi
