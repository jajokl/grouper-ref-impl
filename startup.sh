#!/bin/bash

swarm_mode=`docker info | egrep "^Swarm" | awk '{ print $2 }'`

if [ ${swarm_mode} != "active" ]; then
    echo ""
    echo "ABORTING: This reference implementation requires that Docker Swarm be enabled"
    echo ""
    exit 1
fi

docker stack deploy -c docker-compose.yml grouper
exit 0
