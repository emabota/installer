#!/bin/bash

cwd=`basename \`pwd\``

if [ "$cwd" == "makeself" ]; then
    echo -e "\nDO NOT REPLACE __CONTAINER_VER__ TOKENS IN ORIGINAL INSTALLER SCRIPT TEMPLATE!\n\nPlease run \"./build-local.sh\" from the root of the repo.\n"
    exit
fi

echo "Replacing with __POC_VERSION__/$latest_poc, __MYSQL_VERSION/$latest_mysql, __TOMCAT_VERSION__/$latest_tomcat"

sed -i "s/__POC_VERSION__/$latest_poc/g; s/__MYSQL_VERSION__/$latest_mysql/g; s/__TOMCAT_VERSION__/$latest_tomcat/g" ./install-esaude/install-eSaude.sh
