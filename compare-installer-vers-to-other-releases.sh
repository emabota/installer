#!/bin/bash
. ./makeself/install-esaude/get_version.sh
. ./get-latest-container-ver-num.sh

this_releases_versions=`curl -u $BINTRAY_APIUSER:$BINTRAY_APIKEY https://api.bintray.com/packages/esaude/installer/installer/versions/$installer_version --data attribute_values=1`

echo "$this_releases_versions"

POC_Ver=`echo "$this_releases_versions" | jq '.attributes.POC_Ver[]' | sed 's/"//g'`
Platform_Ver=`echo "$this_releases_versions" | jq 'attributes.Platform_Ver[]' | sed 's/"//g'`

dpkg --compare-versions "$POC_Ver" ge "$latest_poc"
poc_req="$?"
dpkg --compare-versions "$Platform_Ver" ge "$latest_tomcat" 
plat_req="$?"

export NEW_VERSION=$(( poc_req+plat_req ))
