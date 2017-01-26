#!/bin/bash -e

MACHINE=default

docker-machine stop $MACHINE
VBoxManage modifyvm $MACHINE --cpus 2
VBoxManage modifyvm $MACHINE --memory 4096
docker-machine start $MACHINE
