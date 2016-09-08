#!/bin/bash

set -e

DIR=$(cd $(dirname $0)/../.. && pwd)

# Although we should have Perl parse things, we cannot assume we have anything
# installed other than bash, so let's use that.
VERSION=$(grep VERSION $DIR/lib/App/SimsLoader.pm | cut -d\' -f 2 )

function build () {
  local purpose=$1

  docker build \
    --tag robkinyon/sims_loader:$VERSION \
    --file Dockerfile.$purpose \
    $DIR
}

build "base"
#build "mysql"
