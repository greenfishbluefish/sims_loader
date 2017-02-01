#!/bin/bash

set -e

DIR=$(git rev-parse --show-toplevel)

function cleanup-line-endings () {
  # Windows does stupid things to line-endings. Make sure all the files have
  # Unix line-endings in order to function properly in the container.
  for dirname in bin devops lib; do
    find $DIR/$dirname -type f -exec dos2unix -q {} \;
  done
}

function build-base () {
  docker build \
    --tag  "robkinyon/sims_loader_base:latest" \
    --file Dockerfile.base \
      $DIR
}
