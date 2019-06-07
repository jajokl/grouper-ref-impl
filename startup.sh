#!/bin/bash

swarm_mode=`docker info | egrep "^Swarm" | awk '{ print $2 }'`

if [ ${swarm_mode} != "active" ]; then
    echo ""
    echo "ABORTING: This reference implementation requires that Docker Swarm be enabled"
    echo ""
    exit 1
fi

docker ps -a | grep -s -q "grouperRI_" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo ""
    echo "ABORTING: grouperRI containers are still running.  See: docker ps -a"
    echo "          Please wait for all containers to shut down before restarting the stack."
    echo ""
    exit 1
fi

docker stack deploy -c docker-compose.yml grouperRI
echo ""
echo "The startup time for this Grouper stack is typically one to two minutes, longer if you are not running"
echo "on SSD storage. The initial database setup is included in this start time.  Grouper by itself, without"
echo "the database initialization, will typically start more quickly.  Be patient."
echo ""
echo "You can watch the grouper_ui container logs (where the database prep is performed) for status."
echo ""
exit 0







