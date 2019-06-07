1) Ensure that your docker environment has Docker Swarm enabled.
   - docker swarm init | tee swarm_init.txt
   - chmod 400 swarm_init.txt
   You don't need multiple nodes in the swarm, just enabling your test device is fine.
   The reference implementation relies on Docker Secrets and needs a swarm environment.

2) Clean Restart
This is Step 2 so that you'll read it now - you certainly do not want to do
any of these steps now.  You most likely won't need a clean restart, but if
you are running into weird issues after multiple attempts to use the reference
implementation, it may be time to clean up all of the docker stuff and start
fresh.  The instructions below will work to clean all up most of docker on
your machine.  If you are running other docker services on the machine, you
will **NOT** want to follow these instructions directly.
a) docker stack rm grouper; sleep 120
b) docker rm $(docker ps -a) # just in case something hasn't completed
c) docker ps -a # if you see anything, repeat (b)
d) yes | docker volume prune
e) docker rmi $(docker image ls -aq)

3) Extract the tarball into an empty directory and cd into grouper - we call this directory HOME
   - if you are reading this, you have already done that

4) cd grouper_cfg
   a) ./build.sh
   b) ./start-cfg.sh
   c) browse to: http://localhost/
      - fill in the form
        - select local password authentication; shibboleth works but I have a bit more documentation
          to complete on where to place certificates, etc.
      - download the file
      - place the config file into HOME
   d) ./stop-cfg

5) cd HOME
6) ./setup_grouper.sh
7) ./build.sh
8) ./startup.sh
9) wait a few minutes

10) browse to: https://localhost/grouper/ or http://localhost/grouper if you
don't want to deal with browser exceptions

11) login with the admin credentials you entered into the webform
   - the provision_to attribute values configured in the loader are psp_User and psp_groupOfNames
   - ldapsearch -x -h localhost -b ou=People,dc=myschool,dc=edu '(uid=*)'
   - ldapsearch -x -h localhost -b ou=Groups,dc=myschool,dc=edu '(cn=*groupname*)'


12) when done -- docker stack rm grouper

13) to get a new database for testing, wait for two or three minutes after
step 11, then run "docker volume prune" (follow with a docker volume ls to make
sure they are gone); If you have other docker volumes that you need to preserve,
explicitely delete the volumes named: grouper_grouper_ldap,
grouper_grouper_ldap_etc and grouper_grouper_mysql

