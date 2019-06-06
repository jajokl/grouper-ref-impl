#!/bin/bash -x
#
docker build -f Dockerfile-mariadb -t my/mariadb .
exit $?
