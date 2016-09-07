#!/bin/bash

set -e

VERSION="0.001"

DIR=$(cd $(dirname $0)/../.. && pwd)

function build () {
  local purpose=$1

  docker build \
    --tag robkinyon/sims_loader:$VERSION \
    --file Dockerfile.$purpose \
    $DIR
}

build "base"
#build "mysql"
