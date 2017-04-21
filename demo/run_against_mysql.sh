#!/bin/bash

DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)

subcmd=$1
shift

$DIR/run \
  $subcmd \
  --driver mysql \
  --host 192.168.99.100 \
  --username root \
  --schema demo \
    $@
