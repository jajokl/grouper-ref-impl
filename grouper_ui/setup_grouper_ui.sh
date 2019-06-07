#!/bin/bash

#
# setup_grouper_ui.sh
# The script to be run by the system administrator to configure the grouper ui
#
# Note that this script is often run by another higher-level package setup script.
#

CAMPUS_SUPPLIED_FILES="../campus_data"

GROUPER_INSTITUTION_NAME=${GROUPER_INSTITUTION_NAME:-None}
if [ "${GROUPER_INSTITUTION_NAME}" = "None" ]; then
    echo -n "Grouper: enter the full name of your institution/school: "
    read full_school_name
    echo $full_school_name
    echo "institutionName = ${full_school_name}" > grouper.text.en.us.properties

    SH=${SECRET_HOMEDIR:-None}
    if [ "${SH}" != "None" ]; then
        cp grouper.text.en.us.properties ${SH}/grouper
    fi
fi


#
# Create a htpasswd file in case local authentication is being used
#

GROUPER_ADMIN_LOCAL_PASSWORD=${GROUPER_ADMIN_LOCAL_PASSWORD:-unknownjunk}
BASE_UNAME=`echo ${GROUPER_ADMIN_USER} | sed 's/@/ /' | awk '{ print $1 }'`
echo "${GROUPER_ADMIN_LOCAL_PASSWORD}" | htpasswd -c -i grouper_htpasswd "${GROUPER_ADMIN_USER}"
echo "${GROUPER_ADMIN_LOCAL_PASSWORD}" | htpasswd -i grouper_htpasswd "${BASE_UNAME}"


#
# Make sure that we have Apache and Shibboleth certificates and keys
#

if [ ! -f ${CAMPUS_SUPPLIED_FILES}/server_ssl.crt -o ! -f ${CAMPUS_SUPPLIED_FILES}/server_ssl.key ]; then
    openssl req -x509 -newkey rsa:2048 -nodes -keyout ${CAMPUS_SUPPLIED_FILES}/server_ssl.key -out ${CAMPUS_SUPPLIED_FILES}/server_ssl.crt -days 1000 -subj "/C=US/O=SelfSign/CN=localhost"
    echo ""
    echo "Did not find web server ssl certificate or key, created self-signed: ${CAMPUS_SUPPLIED_FILES}/server_ssl.crt server_ssl.key"
    echo ""
fi

if [ ! -f ${CAMPUS_SUPPLIED_FILES}/shib_sp-cert.pem -o ! -f ${CAMPUS_SUPPLIED_FILES}/shib_sp-key.pem ]; then
    openssl req -x509 -newkey rsa:2048 -nodes -keyout ${CAMPUS_SUPPLIED_FILES}/shib_sp-key.pem -out ${CAMPUS_SUPPLIED_FILES}/shib_sp-cert.pem -days 1000 -subj "/C=US/O=SelfSign/CN=Shib-localhost"
    echo ""
    echo "Did not find Shibboleth certificate or key, created self-signed: ${CAMPUS_SUPPLIED_FILES}/shib_sp-cert.pem shib_sp-key.pem"
    echo ""
fi

#
# Remaining Work
#

if [ -f ${CAMPUS_SUPPLIED_FILES}/favicon.ico ]; then
    ln -f ${CAMPUS_SUPPLIED_FILES}/favicon.ico campus_files/favicon.ico
    FILE_FAVICON_ICO="COPY campus_files/favicon.ico /opt/grouper/grouper.ui/grouperExternal/public/assets/images/"
else
    FILE_FAVICON_ICO='# favicon.ico'
fi

if [ -f ${CAMPUS_SUPPLIED_FILES}/server_ssl.crt ]; then
    ln -f ${CAMPUS_SUPPLIED_FILES}/server_ssl.crt campus_files/host-cert.pem
    FILE_HOST_CERT_PEM="COPY campus_files/host-cert.pem /etc/pki/tls/certs/"
    cp ${CAMPUS_SUPPLIED_FILES}/server_ssl.key ../secrets/certs
    cp ${CAMPUS_SUPPLIED_FILES}/server_ssl.crt ../secrets/certs
else
    FILE_HOST_CERT_PEM='# hostcert.pem'
fi

if [ -f ${CAMPUS_SUPPLIED_FILES}/cachain.pem ]; then
    ln -f ${CAMPUS_SUPPLIED_FILES}/cachain.pem campus_files/cachain.pem
    FILE_CACHAIN_PEM="COPY campus_files/cachain.pem /etc/pki/tls/certs/"
else
    FILE_CACHAIN_PEM='# cachain.pem'
fi

if [ -f ${CAMPUS_SUPPLIED_FILES}/school_logo.png ]; then
    ln -f ${CAMPUS_SUPPLIED_FILES}/school_logo.png campus_files/school_logo.png
    FILE_SCHOOL_LOGO_PNG="COPY campus_files/school_logo.png /opt/grouper/grouper.ui/grouperExternal/public/assets/images/"
else
    FILE_SCHOOL_LOGO_PNG='# school_logo.png'
fi

if [ -f ${CAMPUS_SUPPLIED_FILES}/shib_sp-cert.pem ]; then
    cp ${CAMPUS_SUPPLIED_FILES}/shib_sp-cert.pem  ../secrets/certs/
    cp ${CAMPUS_SUPPLIED_FILES}/shib_sp-key.pem ../secrets/certs/
fi


cat <<-EOF > Dockerfile-grouper-ui
FROM tier/grouper:${ITAP_GROUPER_VERSION}

RUN yum -y update
${FILE_FAVICON_ICO}
COPY ui /usr/local/bin
${FILE_HOST_CERT_PEM}
${FILE_CACHAIN_PEM}
COPY ssl-enabled.conf shib.conf /etc/httpd/conf.d/
COPY printenv /var/www/cgi-bin
RUN mkdir /var/www/cgi-bin/secure
COPY printenv /var/www/cgi-bin/secure/
COPY grouper_htpasswd /etc/httpd


${FILE_SCHOOL_LOGO_PNG}
#COPY grouper.text.en.us.properties /opt/grouper/grouper.ui/WEB-INF/classes/grouperText

CMD ui

EOF

exit 0

