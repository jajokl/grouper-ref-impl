#!/bin/bash

#
# setup_ldap.sh
# The script to be run by the system administrator to configure an openldap for TIER
# midPoint and COmanage.
#
# Note that this script is often run by another higher-level package setup script.
#
# Both burned secrets (passwords and keys) and docker swarm secrets are supported.
#
#

HOMEDIR=.
#
LOGFILE=${HOMEDIR}/setup_ldap.log
FILE_TO_EDIT_SOURCE=${HOMEDIR}/ldap/config_ldap_template.sh
FILE_TO_EDIT_DESTINATION=${HOMEDIR}/ldap/config_ldap.sh
TMPFILE=${HOMEDIR}/script_edit_tmpfile.sed

#
# Set up controls for if we prompt the user or not - e.g., values from environment
# A value of Yes in the environment means to not prompt the user
#

#printenv | sort

LDAP_CONFIGURE_NOPROMPT=${LDAP_CONFIGURE_NOPROMPT:-No}

#
# Set up variables below
#

ALL_DONE="No"
while [ ${ALL_DONE} == "No" ]; do
#
#
DB_PASSWORD="None"
DB_PASSWORD_DEF="The1Root2Db3Password"
DB_PASSWORD_PROMPT="Enter the ldap database root password"
DB_PASSWORD_MINLEN=8
#
DM_PASSWORD="None"
DM_PASSWORD_DEF="The1Directory2Manager3Password"
DM_PASSWORD_PROMPT="Enter the ldap Directory Manager password"
DM_PASSWORD_MINLEN=8
#
SH_PASSWORD="None"
SH_PASSWORD_DEF="The1Shibboleth2User3Password"
SH_PASSWORD_PROMPT="Enter the shibboleth user record password"
SH_PASSWORD_MINLEN=8
#
OT_PASSWORD="None"
OT_PASSWORD_DEF="A1long3Password5For7The7Other9Identities"
OT_PASSWORD_PROMPT="Enter the password for the Other Identities created by this script (make strong and/or look)"
OT_PASSWORD_MINLEN=8
#
BASE_DOMAIN="None"
BASE_DOMAIN_DEF="dc=myschool,dc=edu"
BASE_DOMAIN_PROMPT="Enter the base domain of your organization"
BASE_DOMAIN_MINLEN=10
#
ADD_DEMOUSERS="None"
ADD_DEMOUSERS_DEF="Yes"
ADD_DEMOUSERS_PROMPT="Add demo users (useful for midpoint)"
ADD_DEMOUSERS_MINLEN=1
#
SWARM_MODE="None"
SWARM_MODE_DEF="Yes"
SWARM_MODE_PROMPT="Are you running in Swarm mode with Docker Secrets"
SWARM_MODE_MINLEN=2
#
SWARM_MODE_SECRETDIR="None"
SWARM_MODE_SECRETDIR_DEF="../secrets/openldap"
SWARM_MODE_SECRETDIR_PROMPT="Directory to hold secret files"
SWARM_MODE_SECRETDIR_MINLEN=3
#

VARIABLE_NAMES="DB_PASSWORD DM_PASSWORD SH_PASSWORD OT_PASSWORD BASE_DOMAIN ADD_DEMOUSERS SWARM_MODE SWARM_MODE_SECRETDIR"

#
# The main work starts below
#
# Remember that the _ENV versions of these variables can be used to over-ride the _DEF values
#
echo ""
echo ""
echo "Starting the setup configuration for TIER OpenLdap"
echo ""
for variable in ${VARIABLE_NAMES}; do
	VNAME=${variable}
	while [ ${!VNAME} == "None" ]; do
		ok_env=0
		VNAME_DEF=${VNAME}_DEF
		VNAME_PROMPT=${VNAME}_PROMPT
		VNAME_MINLEN=${VNAME}_MINLEN
		VNAME_ENV=${VNAME}_ENV
		ZZZZZ="${!VNAME_ENV:-None}"
		if [ "${ZZZZZ}" != "None" ]; then
			eval ${VNAME_DEF}="${ZZZZZ}"
			ok_env=1
		fi
		# echo "${VNAME}: ok_env ${ok_env}  LDNP: ${LDAP_CONFIGURE_NOPROMPT}   ZZ: $ZZZZZ  VNAME_DEF: ${VNAME_DEF}    VNAME_ENV: ${VNAME_ENV}   VNAME_ENV: ${!VNAME_ENV}"
		if [ "${ok_env}" -eq 1 -a "${LDAP_CONFIGURE_NOPROMPT}" = "Yes" ]; then
			response=${!VNAME_DEF}
		else
			echo -n "${!VNAME_PROMPT} [${!VNAME_DEF}]: "
			read response
		fi
	    if [ ${#response} -eq 0 ]; then
			response=${!VNAME_DEF}
		elif [ ${#response} -lt ${!VNAME_MINLEN} ]; then
			echo "You response requires ${!VNAME_MINLEN} or more characters"
			if [ "${LDAP_CONFIGURE_NOPROMPT}" = "Yes" ]; then
				exit 1
			fi
			continue
		elif [[ ${response} == *"|"* ]]; then
			echo "You can not use the character '|' in a response"
			if [ "${LDAP_CONFIGURE_NOPROMPT}" = "Yes" ]; then
				exit 1
			fi
			continue
		fi
		break
	done
	eval ${VNAME}="$response"
	#echo ""
done
echo ""
echo "You have entered the following values for openldap configuration:"
for variable in ${VARIABLE_NAMES}; do
	echo "$variable  ${!variable}"
done

echo ""
if [ "${LDAP_CONFIGURE_NOPROMPT}" = "Yes" ]; then
	ALL_OK=Yes
	ALL_DONE=Yes
else
	ALL_OK=None
fi
while [ ${ALL_OK} == "None" ]; do
    echo -n "Are all of these values correct [Yes/No]? "
    read response
    case $response in
        Yes|yes|Y|y)
            ALL_OK="Yes"
            ;;
        No|no|N|n)
            ALL_OK="No"
            ;;
    esac
	if [ $ALL_OK == "Yes" ]; then
		ALL_DONE="Yes"
		break
	elif [ $ALL_OK == "No" ]; then
		break
	fi
done
# close the outer ALL_DONE loop
done

#
# OK here we have read all of the variables - time to edit files
#    we are generating config_ldap.sh from config_ldap_template.sh
#    TODO: be able to select if to load the demo data for midPoint
#
> $TMPFILE
for variable in ${VARIABLE_NAMES}; do
	echo "s|${variable}_VAL|${!variable}|g" >> $TMPFILE
done
sed -f ${TMPFILE} < ${FILE_TO_EDIT_SOURCE} > ${FILE_TO_EDIT_DESTINATION}

#
# OK, if no certificates exist, we'll create some self-signed ones
#
if [ ! -f ldap/ldap.crt -a ! -f ldap/ldap.key ]; then
    openssl req -x509 -newkey rsa:2048 -nodes -keyout ldap/ldap.key -out ldap/ldap.crt -days 1000 -subj "/C=US/O=SelfSign/CN=tier-openldap"
    echo "Didn't find certificates, created self-signed: ldap/ldap.key ldap/ldap/crt"
fi

#
# Finally, create Dockerfile-openldap, move secrets to appropriate location
#
if [ -f Dockerfile-openldap ]; then
	#mv --backup=t Dockerfile-openldap Dockerfile-openldap.old
	mv Dockerfile-openldap Dockerfile-openldap.old
fi

#
# Target for copies varies for Swarm Secret vs. burned in modes
# in swarm secret mode, the container scripting links in the secrets
#

if [ "${SWARM_MODE}" != "Yes" ]; then
    COPY_CONFIG="COPY ldap/config_ldap.sh /opt/tier/ldap/"
    COPY_CERT_KEY="COPY ldap/ldap.crt ldap/ldap.key /etc/openldap/certs/"
else
    COPY_CERT_KEY=""
    COPY_CONFIG=""

    cp ldap/ldap.crt ${SWARM_MODE_SECRETDIR}
    cp ldap/ldap.key ${SWARM_MODE_SECRETDIR}
    cp ldap/config_ldap.sh  ${SWARM_MODE_SECRETDIR}
fi

cat <<-EOF > Dockerfile-openldap
FROM centos:centos7
MAINTAINER TIER

RUN yum -y update

WORKDIR /root
EXPOSE 389

RUN yum -y install openldap-servers && yum -y install openldap-clients

COPY ldap/ldap.conf /etc/openldap/
COPY ldap/eduperson.ldif ldap/edumember.ldif ldap/midpoint.schema ldap/ldif/midpoint.ldif ldap/nis.ldif ldap/openssh-lpk-openldap.ldif ldap/voperson.ldif /etc/openldap/schema/


COPY ldap/ldif/DB_CONFIG /var/lib/ldap
RUN chown ldap /var/lib/ldap/DB_CONFIG

RUN mkdir /opt/tier && mkdir /opt/tier/ldap && mkdir /opt/tier/ldap/ldif
COPY ldap/run_slapd.sh ldap/ldif/DB_CONFIG /opt/tier/ldap/
COPY ldap/ldif/modules.ldif  /opt/tier/ldap/ldif/
COPY ldap/slapd.conf /etc/openldap/

#
# This next section varies for Swarm vs. burned-in mode
#
#COPY ldap/config_ldap.sh /opt/tier/ldap/
#RUN chmod 755 /opt/tier/ldap/config_ldap.sh
#COPY ldap/ldap.crt ldap/ldap.key /etc/openldap/certs/

${COPY_CERT_KEY}
${COPY_CONFIG}

RUN chmod 755 /opt/tier/ldap/run_slapd.sh

CMD /opt/tier/ldap/run_slapd.sh

EOF

exit 0
