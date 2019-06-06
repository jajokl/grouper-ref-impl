#!/bin/sh

docker stack rm grouper

echo ""
echo "You may also wish to remove the docker volumes if you no longer need the information in the databases"
echo ""
exit 0
