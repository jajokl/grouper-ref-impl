#!/bin/bash

log="/tmp/start.log"

echo "Starting Container: " > $log
date >> $log
echo "" >> $log

FUSEFILE=/var/lib/mysqlmounted/tier-mysql-fuse


if [ ! -f ${FUSEFILE} ]; then

    echo "No fuse file found"
    echo "No fuse file found" >> $log
    set -e

    echo "Checking args" >> $log
    if [ "${1:0:1}" = '-' ]; then
        set -- mysqld_safe "$@" >> $log
    fi

    echo "Setting DataDir: $MYSQL_DATADIR" >> $log
    
    if [ "$CREATE_NEW_DATABASE" == "1" ]; then

        echo "Installing MariaDB" >> $log

        if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]; then
            echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set' >> $log
            echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?' >> $log
            exit 1
        fi
        
        echo 'Running mysql_install_db ...' >> $log
        mysql_install_db --defaults-file=/etc/my.cnf --datadir="$MYSQL_DATADIR" >> $log
        echo 'Finished mysql_install_db' >> $log
        
        # These statements _must_ be on individual lines, and _must_ end with
        # semicolons (no line breaks or comments are permitted).
        # TODO proper SQL escaping on ALL the things D:
        
        tempSqlFile='/tmp/mysql-first-time.sql'
        echo "DELETE FROM mysql.user ;" > $tempSqlFile
        echo "CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;" >> $tempSqlFile
        echo "GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;" >> $tempSqlFile
        echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" >> $tempSqlFile
        echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;" >> $tempSqlFile
        echo "DROP DATABASE IF EXISTS test ;" >> $tempSqlFile

        
        if [ "$MYSQL_DATABASE" != "" ]; then
            echo "flush privileges;" >> "$tempSqlFile"
            echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" >> "$tempSqlFile"
            echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" >> "$tempSqlFile"
            echo "GRANT ALL ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" >> "$tempSqlFile"
            echo "GRANT ALL ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD' ;" >> "$tempSqlFile"
            echo "GRANT ALL ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'$MYSQL_DATABASE.%_i2network' IDENTIFIED BY '$MYSQL_PASSWORD' ;" >> "$tempSqlFile"
            echo "GRANT ALL ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'$MYSQL_DATABASE.%_i2network' IDENTIFIED BY '$MYSQL_PASSWORD' ;" >> "$tempSqlFile"
            echo "GRANT ALL ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'$MYSQL_DATABASE.%_i2network' IDENTIFIED BY '$MYSQL_PASSWORD' ;" >> "$tempSqlFile"
        fi
    
        echo 'FLUSH PRIVILEGES ;' >> "$tempSqlFile"
        # [jvf] mysqld_safe unknown option '--character-set-server=utf8' [FIXME]
        #echo "character-set-server = utf8" >> /etc/my.cnf
        #echo "collation-server = utf8_unicode_ci" >> /etc/my.cnf
        #echo "" >> /etc/my.cnf
        
        echo "Fixing Permissions" >> $log
        chown -R mysql:mysql $MYSQL_DATADIR
        /opt/bin/fix-permissions.sh $MYSQL_DATADIR >> $log
        /opt/bin/fix-permissions.sh /var/log/mariadb/ >> $log
        /opt/bin/fix-permissions.sh /var/run/ >> $log
        echo "Done Fixing Permissions" >> $log
        rm -f /tmp/firsttimerunning
        echo "Creating fuse file(a): ${FUSEFILE}"
        echo "Creating fuse file(a): ${FUSEFILE}" >> $log
        date > ${FUSEFILE}
        /usr/bin/mysqld_safe --init-file="$tempSqlFile" --datadir="$MYSQL_DATADIR"
    else
        echo "Not Creating a MariaDB - Using Existing from DataDir: $MYSQL_DATADIR" >> $log
        rm -f /tmp/firsttimerunning
        echo "Creating fuse file(b): ${FUSEFILE}"
        echo "Creating fuse file(b): ${FUSEFILE}" >> $log
        date > ${FUSEFILE}
        /usr/bin/mysqld_safe --datadir="$MYSQL_DATADIR"
    fi
    echo "Creating fuse file(c): ${FUSEFILE}"
    echo "Creating fuse file(c): ${FUSEFILE}" >> $log
    date > ${FUSEFILE}
    echo "Fuse file contents"
    cat ${FUSEFILE}
else
    echo "Using Existing MariaDB from DataDir: $MYSQL_DATADIR" >> $log
    echo ""
    echo -n "Using existing MariaDB database - fuse file date: "
    cat ${FUSEFILE}
    echo ""
    /usr/bin/mysqld_safe --datadir="$MYSQL_DATADIR"
fi


echo ""
echo "Completing mariadb start.sh"
echo -n "Fuse file date: "
cat "${FUSEFILE}"
echo ""

tail -f $log

exit 0
