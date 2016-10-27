#!/bin/bash

set -e

DIR=$(cd $(dirname $0)/../.. && pwd)

# Although we should have Perl parse things, we cannot assume we have anything
# installed other than bash, so let's use that.
VERSION=$(grep VERSION $DIR/lib/App/SimsLoader.pm | cut -d\' -f 2 )

function build () {
  local purpose=$1

  local tag="robkinyon/sims_loader:$VERSION"

  docker build \
    --tag  $tag \
    --file Dockerfile.$purpose \
    $DIR

  docker push $tag
}

build "base"
#build "mysql"
