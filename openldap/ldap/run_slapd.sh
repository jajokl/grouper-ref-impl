#!/bin/bash
#
# Run slapd in the container.
# If slapd hasn't yet been configured, configure it for TIER
# If Docker Swarm secrets exist, link them into place
# 

# 
# In order for Docker Secrets to work, the script needs to know both the base directory
# path for secrets (/run/secrets in SWARM).  Specify the SERVICE_NAME in the environment
# and override /run/secrets if needed.
#

SECRET_BASEDIR=${SECRET_BASEDIR:-/run/secrets}
SECRET_SERVICE_NAME=${SECRET_SERVICE_NAME:-comanage}

# Swarm mode secret locations
# Called SWARM but ok with other orchestration frameworks
#
SWARM_LDAP_CERT=${SECRET_BASEDIR}/${SECRET_SERVICE_NAME}-openldap-ldap.crt
SWARM_LDAP_KEY=${SECRET_BASEDIR}/${SECRET_SERVICE_NAME}-openldap-ldap.key
SWARM_LDAP_CFGSCRIPT=${SECRET_BASEDIR}/${SECRET_SERVICE_NAME}-openldap-config_ldap.sh

#
# debug
echo "SWARM_LDAP_CERT: ${SWARM_LDAP_CERT}"
echo "SWARM_LDAP_KEY: ${SWARM_LDAP_KEY}"
echo "SWARM_LDAP_CFGSCRIPT: ${SWARM_LDAP_CFGSCRIPT}"
#


# The fuse is set once this version of openldap is configured
FUSE=/var/lib/ldap/tier_config_fuse
DATABASEDIR=/var/lib/ldap
CONFIGDIR=/var/lib/ldap_etc

#
# check for a configured /var/lib/ldap_etc
#

if [ -f ${CONFIGDIR}/slapd.conf ]; then
	echo "Using pre-existing openldap configuration found in the mounted volume"
else
	echo "Creating new openldap instance - copying over /etc/openldap to initialize the service"
	(cd /etc/openldap; tar cf - . ) | (cd ${CONFIGDIR}; tar xf -)
	chown -R ldap ${CONFIGDIR}
	chgrp -R ldap ${CONFIGDIR}
fi

mv /etc/openldap /etc/openldap.dist
ln -s ${CONFIGDIR} /etc/openldap
	

#
#
if [ ! -f ${DATABASEDIR}/DB_CONFIG ]; then
	cp /opt/tier/ldap/DB_CONFIG ${DATABASEDIR}
fi
chown ldap ${DATABASEDIR} ${DATABASEDIR}/DB_CONFIG
chgrp ldap ${DATABASEDIR} ${DATABASEDIR}/DB_CONFIG


#
# Setup to use Swarm secrets, if they exist
#

if [ -f ${SWARM_LDAP_CERT} ]; then
	rm -f /etc/openldap/certs/ldap.crt
	ln -s ${SWARM_LDAP_CERT} /etc/openldap/certs/ldap.crt
fi

if [ -f ${SWARM_LDAP_KEY} ]; then
	rm -f /etc/openldap/certs/ldap.key
	ln -s ${SWARM_LDAP_KEY} /etc/openldap/certs/ldap.key
fi

if [ -f ${SWARM_LDAP_CFGSCRIPT} ]; then
	# alas, can't chmod 755 a docker secret
        echo "run_slapd.sh: Linking in Docker secret for config_ldap.sh"
	rm -f  /opt/tier/ldap/config_ldap.sh
	cp ${SWARM_LDAP_CFGSCRIPT} /tmp
	chmod 755 /tmp/${SECRET_SERVICE_NAME}-openldap-config_ldap.sh
	ln -s /tmp/${SECRET_SERVICE_NAME}-openldap-config_ldap.sh /opt/tier/ldap/config_ldap.sh
	chmod 755 /opt/tier/ldap/config_ldap.sh
fi


#
#
#TEMPORARY
#rsyslogd &

#
# Start slapd and wait for it to boot
# this really should not be a sleep; lazy
#
#/usr/sbin/slapd -u ldap -4 -h "ldapi:/// ldap:/// ldaps:///" -d 0x120 &
#/usr/sbin/slapd -u ldap -4 -h "ldapi:/// ldap:/// ldaps:///" -d any &
/usr/sbin/slapd -u ldap -4 -h "ldapi:/// ldap:/// ldaps:///" -d stats &
#
sleep 20
#
SLAPD_PID=`ps -ax | grep /usr/sbin/slapd | grep -v grep | awk '{ print $1 }'`
if [ ${#SLAPD_PID} -eq 0 ]; then
    exit 1
fi
ps axl
echo SLAP_PID: ${SLAPD_PID}

#
# ok slapd is up and should be working by now, configure if needed
#

if [ ! -f ${FUSE} ]; then
    /opt/tier/ldap/config_ldap.sh
    date > ${FUSE}
else
    echo ""
    echo "Fuse exists, not reconfiguring ldap"
    echo -n "Fuse Timestamp: "
    cat ${FUSE}
    echo ""
fi

#
# OK, running, loop until slapd exits.
#     TODO: replace this with supervisord
#

clean_down() {
    SLAPD_PID=`ps -ax | grep /usr/sbin/slapd | grep -v grep | awk '{ print $1 }'`
    if [ ${#SLAPD_PID} -eq 0 ]; then
        echo "$0: clean_down() no slapd PIDs remain"
	return
    fi
    echo ""
    echo "$0: caught a signal - SIGTERM, SLAPD_PID: $SLAPD_PID"
    kill -TERM $SLAPD_PID
    echo "$0: have sent SIGTERM to PID $SLAPD_PID"
}


trap clean_down SIGTERM

while true; do
    SLAPD_PID=`ps -ax | grep /usr/sbin/slapd | grep -v grep | awk '{ print $1 }'`
    if [ ${#SLAPD_PID} -eq 0 ]; then
	echo "$0: exiting, no slapd PIDs remain"
	exit 0
    fi
    echo "$0: starting to wait for process to exit"
    wait
    sleep 2
done
echo "$0: exiting"
exit 0
