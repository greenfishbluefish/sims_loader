#!/bin/bash

docker kill mysql
docker rm $(docker ps -aq)
