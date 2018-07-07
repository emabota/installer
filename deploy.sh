#!/bin/bash

. ../tinyurl.sh

if [ -z $gdrive_path ]; then
	gdrive help > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo -e "gdrive not found in path\nadd to path or set \$gdrive_path\n"	
		exit
	fi
fi	

if [ -z $TINYCC_APIKEY ]; then
	echo -e "environment for tiny.cc REST API must be configured\n"
	exit
fi

. ./makeself/install-esaude/get_version.sh

pat="https://.*download"

gdrive_url=`gdrive upload --share ./makeself/install-esaude-$installer_version.run | grep $pat -o`

version_shortUrl=`echo "esaude-$installer_version" | sed -e 's/\.//g'`

curl http://tiny.cc/ --data c=rest_api --data m=shorten --data version=2.0.3 --data format=json --data login="$TINYCC_APIUSER" --data apiKey="$TINYCC_APIKEY" --data-urlencode longUrl="$gdrive_url" --data-urlencode shortUrl="$version_shortUrl" -G -L

#fixed literal hash, should not change... any way to recover if lost?
latest_shortUrl="esaude-latest"

curl http://tiny.cc/ --data c=rest_api --data m=edit --data version=2.0.3 --data hash="$latest_shortUrl" --data format=json --data login="$TINYCC_APIUSER" --data apiKey="$TINYCC_APIKEY" --data-urlencode longUrl="$gdrive_url" --data-urlencode shortUrl="$latest_shortUrl" -G -L
