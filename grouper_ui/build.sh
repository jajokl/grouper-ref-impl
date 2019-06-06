#!/bin/bash -x
#
docker build -f Dockerfile-grouper-ui -t my/grouper-ui .
exit $?
