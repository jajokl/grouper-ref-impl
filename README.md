1. Ensure that your docker environment has Docker Swarm enabled.
	  * `docker swarm init | tee swarm_init.txt`
	  * `chmod 400 swarm_init.txt`

	  You don't need multiple nodes in the swarm, just enabling your test device is fine. The reference implementation relies on Docker Secrets and needs a swarm environment.

2. Clean Restart
This is only listed as Step 2 so that you'll read it now - you certainly do not want to perform
any of these steps now.  You most likely won't need a clean restart, but if
you are running into weird issues after multiple attempts to use the reference
implementation, it may be time to clean up all of the docker components and start
fresh.  The instructions below will remove most docker application components on
your machine.  If you are running other docker services on the machine, you
will **NOT** want to follow these instructions directly and will want to make sure
that you preserve what is needed on your machine.
	  * `docker stack rm grouperRI; sleep 120`
	  * `docker rm $(docker ps -a)` # just in case something hasn't completed
	  * `docker ps -a` # if you see anything, repeat the step above
	  * `yes | docker volume prune`
	  * `docker rmi $(docker image ls -aq)`

3. If you are using the tarball distribution, extract it into an empty directory and then cd into grouper.  We call this directory _HOME_.
If you are reading this on your machine, you already have a distribution in place.

4. `cd grouper_cfg`
	  * `./build.sh`
	  * `./start-cfg.sh`
	  * browse to: http://localhost/ and fill in the web form
	    * Select local password authentication; shibboleth works but I have a bit more documentation to complete on where to place certificates, etc.
	    * Press the Submit button and download the file (grouper_config.dat)
	    * Place this config file into HOME
	  * `./stop-cfg`

5. `cd HOME`
6. `./setup_grouper.sh`
7. `./build.sh`
8. `./startup.sh`
9. Wait a couple/few minutes.
The startup process takes approximately a minute on a fast laptop with flash
  storage.  You can watch the grouper_ui container logs to see when Grouper is
  ready for use.  This container does the database preparation/check work on
  startup and other services wait for the UI to be on-line before starting.

10. browse to: https://localhost/grouper/ or http://localhost/grouper if you
don't want to deal with browser exceptions

11. login with the admin credentials you entered into the webform
	  * The `provision_to` attribute values configured in the loader are `psp_User` and `psp_groupOfNames`
	  * `ldapsearch -x -h localhost -b ou=People,dc=myschool,dc=edu '(uid=*)'`
	  * `ldapsearch -x -h localhost -b ou=Groups,dc=myschool,dc=edu '(cn=*groupname*)'`

12. When done
	  * `./shutdown.sh` or `docker stack rm grouperRI`

13. Restarting the Reference Implementation
	  * To restart the service where you left off (i.e., retaining your grouper and ldap databases), just run `./startup.sh`
	  * In order to obtain a new clean database for testing, wait for two or three minutes after
	step 12, then run `docker volume prune` (follow with a `docker volume ls` to make
	sure they are gone).  __If you have other docker volumes that you need to preserve for other applications,__ explicitly delete the volumes named `grouperRI_grouper_ldap`,
    `grouperRI_grouper_ldap_etc`, and `grouperRI_grouper_mysql` instead.
	`docker volume prune` will **delete all docker volumes on your machine**.

### Shibboleth UI Authentication and Other Customization
1. You can replace the ITAP logo with your school's logo by replacing the file  `HOME/campus_data/school_logo.png` before you build.
2. Shibboleth SP authentication for the Grouper UI
    * Recommendation:  bring a simple Apache-based Shibboleth SP on-line, configure it with the appropriate metadata, and test before moving on to the next steps.
    * Place the web server and chain certificates and keys into `HOME/campus_data` using the filenames: `cachain.pem,` `server_ssl.crt,` and `server_ssl.key.`
    * Place your Shibboleth certificate and key into `HOME/campus_data` using the following filenames: `shib_sp-cert.pem,` and `shib_sp-key.pem.`
    * You may also add your IdP metadata to `HOME/campus_metadata` using the filename `idp-metadata.xml` instead of having the setup scripts download the metadata for you via the webform URL.
3. Note that the provided `docker-compose.yml` file mounts secrets on invocation from the secret's tree.  A production Swarm-based Grouper 
	environment will most likely create the secrets via a separate, more protected, process.  The needed secret statements are commented out in the provided `docker-compose.yml` file.
