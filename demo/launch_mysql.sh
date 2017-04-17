#!/bin/bash

docker run \
  --name mysql \
  -p 3306:3306 \
  -e MYSQL_ALLOW_EMPTY_PASSWORD=1 \
  -d \
    mysql:latest

echo "Connect to $(docker-machine ip)"
