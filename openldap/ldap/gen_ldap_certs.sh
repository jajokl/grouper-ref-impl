#!/bin/bash
#
#
# Generate a request and self-signed certificate/key for openssl
#
openssl req -x509 -newkey rsa:2048 -nodes -keyout ldap.key -out ldap.crt -days 1000 -subj "/C=US/O=SelfSign/CN=tier-openldap"
