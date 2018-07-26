#!/bin/bash

help="\nOptions:\n\n-a check bintray for latest versions, rather than manually providing specific versions\n\n"

automated=0

while getopts ":a" opt; do
	case ${opt} in
	  a ) automated=1;;
	  \? ) echo -e $help
	       exit;;
	esac
done

rm -rf makeself-test/

cp -r makeself/ makeself-test/

if [ "$automated" -eq 1 ]; then
    . ./get-latest-container-ver-num.sh
else
    
    echo -e $help

    . ./get-latest-container-ver-num.sh -i

    echo -n "installer_version: " 
    read version

    echo "installer_version=\"$version\"" > makeself-test/install-esaude/get_version.sh


fi

cd makeself-test

. ./local-build-template-replace.sh

./makeself.cmd
