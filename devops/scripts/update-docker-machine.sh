#!/bin/bash -e

MACHINE=default

RAM=4096
CPU=2
DISK=100000

if [[ "$@" == "rebuild" ]]; then
  docker-machine rm "${MACHINE}"
  docker-machine create \
    -d virtualbox \
    --virtualbox-disk-size "${DISK}" \
    --virtualbox-memory "${RAM}" \
    --virtualbox-cpu-count "${CPU}" \
      "${MACHINE}"
else
#  docker-machine stop "${MACHINE}"
  VBoxManage modifyvm "${MACHINE}" --cpus "${CPU}" --memory "${RAM}"
  VBoxManage modifymedium "${MACHINE}/disk.vmdk" --resize "${DISK}"
  docker-machine start "${MACHINE}"
fi
