#!/bin/bash

set -e

DIR=$(git rev-parse --show-toplevel)

# Windows does stupid things to line-endings. Make sure all the files have
# Unix line-endings in order to function properly in the container.
for dirname in bin devops lib; do
  find $DIR/$dirname -type f -exec dos2unix {} \;
done

# Although we should have Perl parse things, we cannot assume we have anything
# installed other than bash, so let's use that.
VERSION=$(grep VERSION $DIR/lib/App/SimsLoader.pm | cut -d\' -f 2 )

function build () {
  local purpose=$1

  local base="robkinyon/sims_loader"
  local version="$base:$VERSION"
  local latest="$base:latest"

  docker build \
    --tag  $version \
    --tag  $latest \
    --file Dockerfile.$purpose \
    $DIR

  docker push $version
  docker push $latest
}

build "base"
