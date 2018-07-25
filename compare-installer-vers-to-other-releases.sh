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


echo "current code-local installer version is $installer_version"

split_ver='[0-9]+(-(rc|a|b){1})?'

local_ver_substring="$installer_version"
rel_ver_substring="$prev_installer_version"
for i in {1..4}; do

	if [ "$i" -eq 4 ]; then
		dot="."
	else
		dot=""
	fi

	if [[ $local_ver_substring =~ $split_ver ]]; then
	
		if [ "$i" -gt 2 ]; then
			code_fix_ver="$code_fix_ver$dot${BASH_REMATCH[0]}"
		fi
			#code_fix_ver=`echo $installer_version | grep -P '(?<=\.)[0-9]+(\-(rc|b|a){1}(?=$)' -o`
			local_ver_substring=${local_ver_substring#*${BASH_REMATCH[0]}}
	else
		#4th ver is optional, only 3 required
		if [ "$i" -lt 4 ]; then
			echo "error parsing code-local version number"
			exit 1
		fi
	fi


	if [[ $rel_ver_substring  =~ $split_ver ]]; then

		#echo "match ${BASH_REMATCH[0]}"

		if [ "$i" -gt 2 ]; then
			rel_fix_ver="$rel_fix_ver$dot${BASH_REMATCH[0]}"
		fi

		rel_ver_substring=${rel_ver_substring#*${BASH_REMATCH[0]}}

#rel_fix_ver=`echo $prev_installer_version | grep -P '(?<=\.)[0-9]+(?=\.)' -o`
	else
		#4th ver is optional, only 3 required
		if [ "$i" -lt 4 ]; then
			echo "error parsing previous release installer version"
			exit 1
		fi
	fi
done

echo "code local fix version is $code_fix_ver"
echo "release fix version is $rel_fix_ver"

dpkg --compare-versions "$rel_fix_ver" ge "$code_fix_ver" 
code_req="$?"

#default to release fix version number
fix_ver=$rel_fix_ver

#if code fix version number is newer, use it instead
if [ "$code_req" > 0 ]; then
	fix_ver=$code_fix_ver
fi

dpkg --compare-versions "$POC_Ver" ne "$latest_poc"
poc_req="$?"
dpkg --compare-versions "$Platform_Ver" ne "$latest_tomcat" 
plat_req="$?"

echo "\$poc_req=$poc_req, \$plat_req=$plat_req, \$code_req=$code_req"

#if there was a new container release or this is a force built release, inc min version
if [ $(( FORCE_BUILD + poc_req + plat_req )) != 0 ]; then
	let "min_ver++"
fi

echo "using .$min_ver.$fix_ver for min.fix ver"

new_installer_version=`echo $prev_installer_version | sed -r "s/\.[0-9]+\.$split_ver.*/\.$min_ver\.$fix_ver/"`

echo "creating new get_version.sh with installer_version=$new_installer_version"

echo "installer_version=\"$new_installer_version\"" > ./makeself/install-esaude/get_version.sh

echo "cat'ing new get_version.sh to console"
cat ./makeself/install-esaude/get_version.sh

export NEW_VERSION=$(( poc_req+plat_req+code_req ))

echo "\$NEW_VERSION=$NEW_VERSION"
