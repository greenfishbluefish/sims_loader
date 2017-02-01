#!/bin/bash

set -e

DIR=$(git rev-parse --show-toplevel)

source "$DIR/devops/packaging/functions.sh"

# Although we should have Perl parse things, we cannot assume we have anything
# installed other than bash, so let's use that.
VERSION=$(grep VERSION $DIR/lib/App/SimsLoader.pm | head -n 1 | cut -d\' -f 2 )

function release () {
  local name="robkinyon/sims_loader"
  local version="$name:$VERSION"
  local latest="$name:latest"

  docker build \
    --tag  $version \
    --tag  $latest \
    --file Dockerfile.release \
      $DIR

  echo "Testing"

  docker push $version
  docker push $latest
}

cleanup-line-endings
build-base
release
