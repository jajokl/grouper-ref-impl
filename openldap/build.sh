#!/bin/bash -x
#
docker build -f Dockerfile-openldap -t my/openldap .
exit $?
