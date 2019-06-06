#!/bin/bash

#
# Build the needed containers
#

DIRECTORIES_WITH_BUILDS="grouper_shared grouper_ui mariadb openldap"
MYPWD=`pwd`

for dir in ${DIRECTORIES_WITH_BUILDS}; do
    echo ""
    echo "starting build process in ${dir}"
    cd ${dir}
    ./build.sh
    cmdstat=$?
    cd ${MYPWD}
    echo "Ending build process in ${dir}"
    if [ "${cmdstat}" -ne 0 ]; then
        echo ""
        echo ""
        echo "Something went wrong, non-zero return code: $cmdstat"
        echo ""
        exit 1
    fi
    echo ""
done

