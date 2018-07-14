#!/bin/bash
#import current code-local version number ($installer_version)
. ./makeself/install-esaude/get_version.sh
#import $latest_poc, $latest_tomcat, $latest_mysql (latest publised container versions retrieved from bintray)
. ./get-latest-container-ver-num.sh

echo "Querying Bintray REST API"
prev_releases_versions=`curl -u $BINTRAY_APIUSER:$BINTRAY_APIKEY https://api.bintray.com/packages/esaude/installer/installer/versions/_latest --data attribute_values=1 -G`

echo "Response: $prev_releases_versions"

echo "using jq to parse response"

prev_installer_version=`echo "$prev_releases_versions" | jq '.name' | sed 's/"//g'`
echo "\$prev_installer_version==$prev_installer_version"

POC_Ver=`echo "$prev_releases_versions" | jq '.attributes.POC_Ver[]' | sed 's/"//g'`
echo "\$POC_Ver==$POC_Ver"

Platform_Ver=`echo "$prev_releases_versions" | jq '.attributes.Platform_Ver[]' | sed 's/"//g'`
echo "\$Platform_Ver==$Platform_Ver"

min_ver=`echo $prev_installer_version | grep -P '(?<=\.)[0-9]+(?=\.)' -o`
let "min_ver++"

code_fix_ver=`echo $installer_version | grep -P '(?<=\.)[0-9|(rc|b|a)]+(?=$)' -o`
rel_fix_ver=`echo $prev_installer_version | grep -P '(?<=\.)[0-9]+(?=\.)' -o`

dpkg --compare-versions "$rel_fix_ver" ge "$code_fix_ver" 
code_req="$?"

new_installer_version=`echo $prev_installer_version | sed -r "s/\.[0-9]+\./\.$min_ver\./"`

echo "installer_version=\"$new_installer_version\"" > ./makeself/install-esaude/get_version.sh

echo "cat'ing new get_version.sh to console"
cat ./makeself/install-esaude/get_version.sh

dpkg --compare-versions "$POC_Ver" ge "$latest_poc"
poc_req="$?"
dpkg --compare-versions "$Platform_Ver" ge "$latest_tomcat" 
plat_req="$?"

echo "\$poc_req=$poc_req, \$plat_req=$plat_req"

export NEW_VERSION=$(( poc_req+plat_req+code_req ))

echo "\$NEW_VERSION=$NEW_VERSION"
