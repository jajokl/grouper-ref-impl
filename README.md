1) Ensure that your docker environment has Docker Swarm enabled.
   - docker swarm init | tee swarm_init.txt
   - chmod 400 swarm_init.txt
   You don't need multiple nodes in the swarm, just enabling your test device is fine.
   The reference implementation relies on Docker Secrets and needs a swarm environment.

2) Extract the tarball into an empty directory and cd into grouper - we call this directory HOME
   - if you are reading this, you have already done that

3) cd grouper_cfg
   a) ./build.sh
   b) ./start-cfg.sh
   c) browse to: http://localhost/
      - fill in the form
        - select local password authentication; shibboleth works but I have a bit more documentation
          to complete on where to place certificates, etc.
      - download the file
      - place the config file into HOME
   d) ./stop-cfg

4) cd HOME
5) ./setup_grouper.sh
6) ./build.sh
7) ./startup.sh
8) wait a few minutes

9) browse to: https://localhost/grouper/ or http://localhost/grouper if you
don't want to deal with browser exceptions

10) login with the admin credentials you entered into the webform
   - the provision_to attribute values configured in the loader are psp_User and psp_groupOfNames
   - ldapsearch -x -h localhost -b ou=People,dc=myschool,dc=edu '(uid=*)'
   - ldapsearch -x -h localhost -b ou=Groups,dc=myschool,dc=edu '(cn=*groupname*)'


11) when done -- docker stack rm grouper

12) to get a new database for testing, wait for two or three minutes after
step 10, then run "docker volume prune" (follow with a docker volume ls to make
sure they are gone); If you have other docker volumes that you need to preserve,
explicitely delete the volumes named: grouper_grouper_ldap,
grouper_grouper_ldap_etc and grouper_grouper_mysql

