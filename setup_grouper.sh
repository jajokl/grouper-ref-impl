#!/bin/bash
#
# Setup TIER Grouper Reference Implementation
#

DISTRIB_DIRS="campus_data grouper_shared environment mariadb openldap grouper_ui secrets secrets/openldap secrets/grouper secrets/shib"
CONTAINER_DIRS="grouper_shared mariadb openldap grouper_ui"
SCRIPT_HOMEDIR=`pwd`
SECRET_HOMEDIR="${SCRIPT_HOMEDIR}/secrets"

export SECRET_HOMEDIR

#
# Check to make sure we are in a grouper distro tree
#

for dir in ${DISTRIB_DIRS}; do
    if [ ! -d "${dir}" ]; then
        echo "$0: you are not running this script from within the grouper directory, no directory: " ${dir}
        exit 1
    fi
done

#
# Load configuration values
#

if [ ! -f ./grouper_config.dat ]; then
    echo ""
    echo "setup_grouper.sh: no configuration file ./grouper_config.dat found"
    echo "Have you run the GUI configuration container (grouper_cfg) yet?"
    echo "ABORTING"
    exit 1
fi

. ./grouper_config.dat

#
# Handle the grouper subject source authentication question
#

SUBJECT_SRC_NEEDS_AUTHN=${GROUPER_LDAP_SUBJECT_SOURCE_PRINCIPAL:-No}
if [ "${SUBJECT_SRC_NEEDS_AUTHN}" = "No" ]; then
    SUBJECT_SOURCE_AUTH_COMMENT="#"
else
    SUBJECT_SOURCE_AUTH_COMMENT=""
fi

#
# Build the grouper configuration files before the individual container tuning as
# these files are used by more than one container.
#

if [ ${GROUPER_AUTHENTICATION_MODE} = "SHIBBOLETH" ]; then
    GROUPER_AUTHENTICATION_STRING="# - httpd_grouper-www.conf"
    URL=${SHIBBOLETH_IDP_METADATA_URL:-None}
    if [ ${URL} != "None" ]; then
        wget --no-check-certificate -O ${SECRET_HOMEDIR}/shib/idp-metadata.xml ${URL}
        if [ $? -ne 0 ]; then
            echo ""
            echo "Unable to download Shibboleth IdP metadata -- ABORTING -- ${URL}"
            echo ""
            exit 1
        fi
    elif [ -f {SCRIPT_HOMEDIR}/campus_data/idp-metadata.xml ]; then
        cp {SCRIPT_HOMEDIR}/campus_data/idp-metadata.xml ${SECRET_HOMEDIR}/shib/idp-metadata.xml
    else
        echo ""
        echo "ABORTING Fatal error: no idp-metadata.xml : Shibboleth authentication selected and no download URL or file in campus_files"
        echo ""
        exit 1
    fi
else
    GROUPER_AUTHENTICATION_STRING="- httpd_grouper-www.conf"
    echo "Empty file placeholder for non-Shibboleth authentication"
    echo "" > ${SECRET_HOMEDIR}/shib/idp-metadata.xml
    SHIBBOLETH_IDP_ENTITY_ID=${SHIBBOLETH_IDP_ENTITY_ID:-https://localhost/shibboleth}
    SHIBBOLETH_SP_ENTITY_ID=${SHIBBOLETH_SP_ENTITY_ID:-'urn:mace:yourschool.edu'}
fi

# first, generate the sed script to edit the template files

cat <<-EOF > ${SECRET_HOMEDIR}/edits.sed
s|\\\${ITAP_GROUPER_VERSION}|${ITAP_GROUPER_VERSION}|g
s|\\\${GROUPER_INSTITUTION_NAME}|${GROUPER_INSTITUTION_NAME}|g
s|\\\${HOST_FQDN}|${GROUPER_UI_HOST_FQDN}|g
s|\\\${GROUPER_ADMIN_USER}|${GROUPER_ADMIN_USER}|g
s|\\\${LDAP_DCDOMAIN}|${LDAP_DCDOMAIN}|g
s|\\\${LDAP_DM_PASSWORD}|${LDAP_DM_PASSWORD}|g
s|\\\${DB_USER_GROUPER_PASSWORD}|${DB_USER_GROUPER_PASSWORD}|g
s|\\\${GROUPER_UI_HOST_FQDN|${GROUPER_UI_HOST_FQDN}|g
s|\\\${GROUPER_LDAP_SUBJECT_SOURCE}|${GROUPER_LDAP_SUBJECT_SOURCE}|g
s|\\\${GROUPER_LDAP_SUBJECT_SOURCE_BASE}|${GROUPER_LDAP_SUBJECT_SOURCE_BASE}|g
s|\\\${GROUPER_LDAP_SUBJECT_SOURCE_PRINCIPAL}|${GROUPER_LDAP_SUBJECT_SOURCE_PRINCIPAL}|g
s|\\\${GROUPER_LDAP_SUBJECT_SOURCE_PASSWORD}|${GROUPER_LDAP_SUBJECT_SOURCE_PASSWORD}|g
s|\\\${GROUPER_LDAP_SUBJECT_SOURCE_ATTRIBUTE}|${GROUPER_LDAP_SUBJECT_SOURCE_ATTRIBUTE}|g
s|\\\${USER_EPPN_DOMAIN}|${USER_EPPN_DOMAIN}|g
s|\\\${SCHOOL_BASE_DOMAIN}|${SCHOOL_BASE_DOMAIN}|g
s|\\\${SUBJECT_SOURCE_AUTH_COMMENT}|${SUBJECT_SOURCE_AUTH_COMMENT}|g
s|\\\${GROUPER_AUTHENTICATION_STRING}|${GROUPER_AUTHENTICATION_STRING}|g
s|\\\${SHIBBOLETH_IDP_ENTITY_ID}|${SHIBBOLETH_IDP_ENTITY_ID}|g
s|\\\${SHIBBOLETH_SP_ENTITY_ID}|${SHIBBOLETH_SP_ENTITY_ID}|g

EOF


# edit the template files to create 

cd ${SECRET_HOMEDIR}/grouper
for tplate_file in *.template; do
    fname=`basename $tplate_file .template`
    if [ -f "$fname" ]; then
        mv "${fname}" "${fname}.old"
    fi
    sed -f ${SECRET_HOMEDIR}/edits.sed "$tplate_file" >  "$fname"
done

cd ${SECRET_HOMEDIR}/shib
sed -f ${SECRET_HOMEDIR}/edits.sed shibboleth2.xml.template > shibboleth2.xml

cd ${SCRIPT_HOMEDIR}
sed -f ${SECRET_HOMEDIR}/edits.sed "docker-compose.yml.template" > docker-compose.yml



#
# Run the configuration scripts
#

for dir in ${CONTAINER_DIRS}; do
    cd ${dir}
    echo "Working on: ${dir}"
    case ${dir} in
      openldap)
        echo "Working on: ${dir}, case openldap"
        DB_PASSWORD_ENV=${LDAP_DB_PASSWORD}; export DB_PASSWORD_ENV
        DM_PASSWORD_ENV=${LDAP_DM_PASSWORD}; export DM_PASSWORD_ENV
        SH_PASSWORD_ENV=${LDAP_SH_PASSWORD}; export SH_PASSWORD_ENV
        OT_PASSWORD_ENV=${LDAP_OT_PASSWORD}; export OT_PASSWORD_ENV
        BASE_DOMAIN_ENV=${LDAP_DCDOMAIN}; export BASE_DOMAIN_ENV
        ADD_DEMOUSERS_ENV=${LDAP_ADD_DEMOUSERS}; export ADD_DEMOUSERS_ENV
        LDAP_CONFIGURE_NOPROMPT=Yes; export LDAP_CONFIGURE_NOPROMPT
        SWARM_MODE_ENV=${LDAP_SWARM_MODE}; export SWARM_MODE_ENV
        SWARM_MODE_SECRETDIR_ENV=${LDAP_SWARM_MODE_SECRETDIR}; export SWARM_MODE_SECRETDIR_ENV

        if [ -f ${SCRIPT_HOMEDIR}/campus_data/openldap/ldap.crt -a -f ${SCRIPT_HOMEDIR}/campus_data/openldap/ldap.key ]; then
            cp ${SCRIPT_HOMEDIR}/campus_data/openldap/ldap.crt ldap
            cp ${SCRIPT_HOMEDIR}/campus_data/openldap/ldap.key ldap
            echo "Using openldap ldap.key found in campus_data directory. Copy made to openldap/ldap"
        fi
        ;;
      mariadb)
        if [ -f ${SECRET_HOMEDIR}/mariadb/db.env ]; then
            mv ${SECRET_HOMEDIR}/mariadb/db.env  ${SECRET_HOMEDIR}/mariadb/db.env.old
        fi
        if [ -f ${SECRET_HOMEDIR}/mariadb/common.env ]; then
            mv ${SECRET_HOMEDIR}/mariadb/common.env  ${SECRET_HOMEDIR}/mariadb/common.env.old
        fi
        cat <<-EOF > ${SECRET_HOMEDIR}/mariadb/db.env
		CREATE_NEW_DATABASE=1
		MYSQL_ROOT_PASSWORD=${DB_USER_ROOT_PWD}
		MYSQL_DATADIR=/var/lib/mysqlmounted
		TERM=dumb
		COMPOSE=true
		#
		MYSQL_DATABASE=grouper
		MYSQL_USER=grouper
		MYSQL_PASSWORD=${DB_USER_GROUPER_PASSWORD}
		#

	EOF

        cat <<-EOF > ${SECRET_HOMEDIR}/mariadb/common.env
		SECRET_SERVICE_NAME=grouper
		SECRET_BASEDIR=/run/secrets
	EOF

        ;;

      grouper_ui)
        # container grouper version edited in directory setup script
        ;;
            
      grouper_shared)
        sed -f ${SECRET_HOMEDIR}/edits.sed Dockerfile-grouper-shared.template > Dockerfile-grouper-shared
        ;;

      *)
        ;;
    esac
    ./setup_${dir}.sh
    ret_val=$?
    cd ${SCRIPT_HOMEDIR}
    if [ "${ret_val}" -ne 0 ]; then
        echo "A setup script had a non-zero return - Aborting: ", ${ret_val}
        break
    fi
done
exit ${ret_val}
