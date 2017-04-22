#!/bin/bash

DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)

subcmd=$1
shift

$DIR/run \
  $subcmd \
  --driver mysql \
  --host 172.17.0.3 \
  --username root \
  --schema demo \
    $@
