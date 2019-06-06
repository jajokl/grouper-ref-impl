#!/bin/bash -x
#
docker build -f Dockerfile-grouper-cfg -t my/grouper-cfg .
exit $?
