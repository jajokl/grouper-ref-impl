#!/bin/bash -x
#
BASEDIR=/opt/tier/ldap
LDIFDIR=${BASEDIR}/ldif
### for testing ###
#BASEDIR=.
#LDIFDIR=.
#
#
cd $BASEDIR
PATH=$PATH:/usr/sbin:/usr/bin; export PATH
#
DB_PASSWORD="DB_PASSWORD_VAL"
DM_PASSWORD="DM_PASSWORD_VAL"
SH_PASSWORD="SH_PASSWORD_VAL"
OT_PASSWORD="OT_PASSWORD_VAL"
#
BASE_DOMAIN="BASE_DOMAIN_VAL"
ADD_DEMOUSERS="ADD_DEMOUSERS_VAL"
#
#
DB_HASH=`/usr/sbin/slappasswd -n -s "$DB_PASSWORD"`
DM_HASH=`/usr/sbin/slappasswd -n -s "$DM_PASSWORD"`
SH_HASH=`/usr/sbin/slappasswd -n -s "$SH_PASSWORD"`
OT_HASH=`/usr/sbin/slappasswd -n -s "$OT_PASSWORD"`
#echo $DB_HASH
#echo $DM_HASH
#echo $SH_HASH

#
# Step 1 - set the database password hash
#

cat <<-EOF > ${LDIFDIR}/chrootpw.ldif
dn: olcDatabase={0}config,cn=config
changetype: modify
add: olcRootPW
olcRootPW: $DB_HASH

EOF

ldapadd -Y EXTERNAL -H ldapi:/// -f ${LDIFDIR}/chrootpw.ldif


# modules
ldapadd -Y EXTERNAL -H ldapi:/// -f ${LDIFDIR}/modules.ldif


#
# Step 2 -- Some Schema additions
#

ldapadd -Y EXTERNAL -H  ldapi:/// -f /etc/openldap/schema/cosine.ldif
ldapadd -Y EXTERNAL -H  ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
ldapadd -Y EXTERNAL -H  ldapi:/// -f /etc/openldap/schema/nis.ldif
ldapadd -Y EXTERNAL -H  ldapi:/// -f /etc/openldap/schema/eduperson.ldif
ldapadd -Y EXTERNAL -H  ldapi:/// -f /etc/openldap/schema/edumember.ldif
ldapadd -Y EXTERNAL -H  ldapi:/// -f /etc/openldap/schema/voperson.ldif


# for COmanage we'll also want
# BREAKAGE NEED TO FIX ldapadd -Y EXTERNAL -H  ldapi:/// -f /etc/openldap/schema/openssh-lpk-openldap.ldif
ldapadd -Y EXTERNAL -H  ldapi:/// -f /etc/openldap/schema/openssh-lpk-openldap.ldif


#ldapadd -Y EXTERNAL -H  ldapi:/// -f /etc/openldap/schema/core.ldif
#ldapadd -Y EXTERNAL -H  ldapi:/// -f /etc/openldap/schema/ppolicy.ldif

#
# add in the midpoint specific schema
#

ldapadd -Y EXTERNAL -H  ldapi:/// -f /etc/openldap/schema/midpoint.ldif

#
# Step 3 - set the Directory Manager password (we'll let midPoint bind here too for now)
#

cat <<-EOF > ${LDIFDIR}/chdomain.ldif
dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read by dn.base="cn=Manager,${BASE_DOMAIN}" read by * none

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: ${BASE_DOMAIN}

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: cn=Manager,${BASE_DOMAIN}

dn: olcDatabase={2}hdb,cn=config
changetype: modify
add: olcRootPW
olcRootPW: ${DM_HASH}

dn: olcDatabase={2}hdb,cn=config
changetype: modify
add: olcAccess
olcAccess: {0}to attrs=userPassword,shadowLastChange by dn="cn=Manager,${BASE_DOMAIN}" write by anonymous auth by self write by * none
olcAccess: {1}to dn.base="" by * read
olcAccess: {2}to * by dn="cn=Manager,${BASE_DOMAIN}" write by * read

EOF


ldapmodify -Y EXTERNAL -H ldapi:/// -f ${LDIFDIR}/chdomain.ldif

#
# Step 4 -- add in the other domains
#
# Creates ou=People, ou=Groups, ou=Services, ou=Administrators, cn=Manager, and cn=idm

cat <<-EOF > ${LDIFDIR}/basedomain.ldif
dn: ${BASE_DOMAIN}
objectClass: top
objectClass: dcObject
objectclass: organization
o: TIER Midpoint

dn: cn=Manager,${BASE_DOMAIN}
objectClass: organizationalRole
cn: Manager
description: Directory Manager

dn: ou=People,${BASE_DOMAIN}
objectClass: organizationalUnit
ou: People

dn: ou=Groups,${BASE_DOMAIN}
objectClass: organizationalUnit
ou: Groups

dn: ou=Services,${BASE_DOMAIN}
objectClass: organizationalUnit
ou: Services

dn: ou=Administrators,${BASE_DOMAIN}
objectClass: organizationalUnit
ou: Administrators

dn: cn=idm,ou=Administrators,${BASE_DOMAIN}
objectclass: top
objectclass: person
cn: idm
sn: IDM Administrator
description: Special LDAP acccount used by the IDM to access the LDAP data.
userPassword: ${OT_HASH}

EOF



ldapadd -x -D cn=Manager,${BASE_DOMAIN} -h 127.0.0.1 -w ${DM_PASSWORD} -f ${LDIFDIR}/basedomain.ldif 


#
# Step 5 - set the Shibboleth read-only password
#

cat <<-EOF > ${LDIFDIR}/add_shib_user.ldif
dn: cn=shibboleth,ou=Services,${BASE_DOMAIN}
objectclass: top
objectclass: person
cn: shibboleth
sn: shibboleth    
description: Shibboleth read-only service account
userPassword: ${SH_HASH}

EOF

ldapadd -x -D cn=Manager,${BASE_DOMAIN} -h 127.0.0.1 -w ${DM_PASSWORD} -f ${LDIFDIR}/add_shib_user.ldif


#
# Step 6 -- some additional functions
#

cat <<-EOF > ${LDIFDIR}/olcAccess_idm.ldif
dn: olcDatabase={2}hdb,cn=config
changetype: modify
add: olcAccess
olcAccess: {0}to attrs=userPassword,shadowLastChange by dn="cn=idm,ou=Administrators,${BASE_DOMAIN}" write by anonymous auth by self write by * none
#olcAccess: {1}to dn.base="" by * read
olcAccess: {2}to * by dn="cn=idm,ou=Administrators,${BASE_DOMAIN}" write by * read

EOF

ldapmodify -Y EXTERNAL -H ldapi:/// -f ${LDIFDIR}/olcAccess_idm.ldif

#
# If requested, add some demo/test users to the directory
#
if [ ${ADD_DEMOUSERS} == "Yes" ]; then

cat <<-EOF > ${LDIFDIR}/example_users.ldif
# based on a sample from midpoint
dn: uid=jbond, ou=People, ${BASE_DOMAIN}
cn: James Bond (007)
sn: Bond
givenname: James
objectclass: top
objectclass: person
objectclass: organizationalPerson
objectclass: inetOrgPerson
ou: Operations
ou: People
o: MI6
l: World
uid: jbond
mail: jbond@myschool.edu
telephonenumber: +1 408 555 1234
facsimiletelephonenumber: +1 408 555 4321
roomnumber: 777
userPassword: ${OT_HASH}
#userpassword: supersecret

dn: uid=cptjack, ou=People, ${BASE_DOMAIN}
cn: cpt. Jack Sparrow
sn: Sparrow
givenname: Jack
objectclass: top
objectclass: person
objectclass: organizationalPerson
objectclass: inetOrgPerson
ou: Operations
ou: People
l: Caribbean
uid: cptjack
mail: jack@myschool.edu
telephonenumber: +421 910 123456
facsimiletelephonenumber: +1 408 555 1111
roomnumber: 666
userPassword: ${OT_HASH}
#userpassword: d3adM3nT3llN0Tal3s

dn: uid=will, ou=People, ${BASE_DOMAIN}
cn: Will Turner
sn: Turner
givenname: William
objectclass: top
objectclass: person
objectclass: organizationalPerson
objectclass: inetOrgPerson
ou: Operations
ou: People
l: Caribbean
uid: will
mail: will@myschool.edu
telephonenumber: +421 910 654321
facsimiletelephonenumber: +1 408 555 1111
roomnumber: 555
userPassword: ${OT_HASH}
#userpassword: elizAb3th

dn: uid=barbossa, ou=People, ${BASE_DOMAIN}
cn: Hector Barbossa
sn: Barbossa
givenname: Hector
objectclass: top
objectclass: person
objectclass: organizationalPerson
objectclass: inetOrgPerson
ou: Operations
ou: People
l: Caribbean
uid: barbossa
mail: captain.barbossa@myschool.edu
telephonenumber: +421 910 382734
facsimiletelephonenumber: +1 408 555 1111
roomnumber: 111
userPassword: ${OT_HASH}
#userpassword: jack

dn: uid=goldfinger, ou=People, ${BASE_DOMAIN}
cn: Auric Goldfinger
sn: Goldfinger
givenname: Auric
objectclass: top
objectclass: person
objectclass: organizationalPerson
objectclass: inetOrgPerson
ou: Operations
ou: People
l: Switzerland
uid: goldfinger
mail: auric.goldfinger@myschool.edu
telephonenumber: +421 867 5309
facsimiletelephonenumber: +1 408 555 1212
roomnumber: 1
userPassword: ${OT_HASH}
#userpassword: ilovegold

dn: uid=adent, ou=People, ${BASE_DOMAIN}
cn: Arthur Dent
sn: Dent
givenname: Arthur
objectclass: top
objectclass: person
objectclass: organizationalPerson
objectclass: inetOrgPerson
objectclass: eduPerson
ou: People
l: England
uid: adent
mail: adent@myschool.org
telephonenumber: +421 427 4242
facsimiletelephonenumber: +1 408 555 1212
roomnumber: 42
userPassword: ${OT_HASH}
#userpassword: ihatevogons

dn: cn=Pirates,ou=groups,${BASE_DOMAIN}
objectclass: top
objectclass: groupOfNames
cn: Pirates
ou: Groups
member: uid=cptjack, ou=People, ${BASE_DOMAIN}
member: uid=will, ou=People, ${BASE_DOMAIN}
member: uid=goldfinger, ou=People, ${BASE_DOMAIN}
description: Arrrrr!

dn: cn=apache,ou=Services,${BASE_DOMAIN}
objectclass: top
objectclass: person
cn: apache
sn: apache
userPassword: ${OT_HASH}
description: Service account for apache web server authentication

dn: cn=jira,ou=Services,${BASE_DOMAIN}
objectclass: top
objectclass: person
cn: jira
sn: jira
userPassword: ${OT_HASH}
description: Service account for Atlassian Jira authentication

EOF

ldapadd -x -w ${DM_PASSWORD} -D cn=Manager,${BASE_DOMAIN} -f ${LDIFDIR}/example_users.ldif
fi

exit 0

