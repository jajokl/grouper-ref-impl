### Introduction

This [Grouper](https://www.internet2.edu/grouper/) InCommon Trusted Access
Platform (TAP) Reference Implementation implements the use case of running
Grouper to manage a LDAP directory leveraging an existing campus LDAP
directory or Active Directory as the source of campus People (Subjects).  The
provided LDAP directory is initially empty and is automatically populated with
users and groups via interaction with the Grouper User Interface and through
Grouper's Loader and Web Services.  The contents of the provided LDAP
directory can be examined using your favorite LDAP search tools.

The scripting and web configuration tools are built so that this Reference
Implementation can be installed on your laptop, configuring Grouper to use
simple password-based authentication, or run on a server fully integrated into
your campus Shibboleth environment.

The Reference Implementation operates in a Docker Swarm environment and
provides containers for OpenLDAP, a MARIADB database for Grouper, and
individual containers for several Grouper roles (UI, loader, web services,
etc.).  The Reference Implementation supports authentication to the Grouper UI
both using simple passwords (ideal for testing on your laptop) and via a
Shibboleth SP (perfect for use by multiple people on a server).  The build's
scripting is designed to work on Linux and MacOS.

This reference is not meant to be deployed into production.  In particular, a
real database with backups and all of the normal infrastructure is needed.
This implementation is useful as a working template for designing your
production implementation as well as early learning and working with Grouper
itself.

### Installation
1. Ensure that your docker environment has Docker Swarm enabled.
	  * `docker swarm init | tee swarm_init.txt`
	  * `chmod 400 swarm_init.txt`

	  You don't need multiple nodes in the swarm.  In fact, the scripting assumes that you do not have multiple swarm nodes (no registry is provided). The reference implementation relies on Docker Secrets and needs a swarm environment.

2. If you are using the tarball distribution, extract it into an empty directory and then cd into grouper.  We call this directory _HOME_.
If you are reading this on your machine, you already have a distribution in place.
To instead obtain a copy from github, `git clone https://github.com/jajokl/grouper-ref-impl` and `cd into grouper-ref-impl`.  This will
now be the _HOME_ directory.

3. `cd grouper_cfg`
	  * `./build.sh`
	  * `./start-cfg.sh`
	  * browse to: http://localhost/ (or the URL of your docker host) and fill in the web form
	    * Select local password authentication; shibboleth works but I have a bit more documentation to complete on where to place certificates, etc.
	    * Press the Submit button and download the file (grouper_config.dat)
	    * Place this config file into HOME
	  * `./stop-cfg`

4. `cd HOME`
5. Optional: `cd campus_data`.
If you enabled Shibboleth-based Grouper authentication in the web configuration tool, you __must__ copy the needed certificates and keys
 into this directory.  The needed files are: `cachain.pem`, `server_ssl.crt`, `server_ssl.key`, `shib_sp-cert.pem`, and `shib_sp-key.pem`.
 You may also add your IdP metadata to `HOME/campus_metadata` using the filename `idp-metadata.xml` instead of having the setup scripts download the metadata for you via the webform URL.
 It is sometumes helpful to bring a simple Apache-based Shibboleth SP on-line, configure it with the appropriate metadata, and test before doing the above steps.
Optionally_, you can replace the InCommon `school_logo.png` and `favicon.ico` files with appropriate campus images.
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
	  * The `etc:pspng:provision_to` attribute values configured in the loader are: `psp_groupOfNames`, `pspng_entitlements`, `pspng_membership`
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

14. Clean Restart
You should not need a clean restart, but if
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


### Known Issues and Discussion
1. Cleanup work remains for some of the configuration files.
2. The configuration web container should be modified so that it can also assist with Shibboleth debugging of the server version of the reference implementation.
3. The provided `docker-compose.yml` file mounts secrets on invocation from the secret's tree.  A production Swarm-based Grouper 
	environment will most likely create the secrets via a separate, more protected, process.  The needed secret statements are commented out in the provided `docker-compose.yml` file.
