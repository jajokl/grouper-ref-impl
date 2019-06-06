#!/bin/bash -x
#
docker build -f Dockerfile-grouper-shared -t my/grouper-shared .
exit $?
