#!/bin/sh

docker stack rm grouperRI

echo ""
echo "You may also wish to remove the docker volumes if you no longer need the information in the databases"
echo ""
echo "Note that the grouper stack can take a minute or two to fully shut down.  You can change this timing"
echo "if desired.  The current settings leave ample time for the applications to cleanly shut down before"
echo "the databases stop.   docker ps -a  will list any containers that have not completed their shutdown."
echo ""
exit 0
