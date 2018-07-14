#!/bin/bash
. ./makeself/install-esaude/get_version.sh

echo "Querying Bintray REST API"
this_releases_versions=`curl -u $BINTRAY_APIUSER:$BINTRAY_APIKEY https://api.bintray.com/packages/esaude/installer/installer/versions/_latest --data attribute_values=1`

echo "Response"
echo "$this_releases_versions"

echo "using jq to parse response"
new_installer_version=`echo "$this_releases_versions" | jq '.name[]' | sed 's/"//g'`
POC_Ver=`echo "$this_releases_versions" | jq '.attributes.POC_Ver[]' | sed 's/"//g'`
Platform_Ver=`echo "$this_releases_versions" | jq '.attributes.Platform_Ver[]' | sed 's/"//g'`

min_ver=`echo $new_installer_version | grep -P '(?<=\.)[0-9]+(?=\.)' -o`
let "min_ver++"
new_installer_version=`echo $new_installer_version | sed -r "s/\.[0-9]+\./$min_ver/"`

echo "installer_version=$new_installer_version" > ./makeself/install-esaude/get_version.sh

cat ./makeself/install-esaude/get_version.sh

dpkg --compare-versions "$POC_Ver" ge "$latest_poc"
poc_req="$?"
dpkg --compare-versions "$Platform_Ver" ge "$latest_tomcat" 
plat_req="$?"

export NEW_VERSION=$(( poc_req+plat_req ))
