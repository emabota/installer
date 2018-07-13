#!/bin/bash

vars=("latest_mysql" "latest_tomcat" "latest_poc")
pkgs=("platform-docker/mysql" "platform-docker/tomcat" "poc-docker/poc")

index=0
for pkg in ${pkgs[@]}; do
	echo ${vars[$index]}

		
	eval "${vars[$index]}=`curl https://api.bintray.com/packages/esaude/$pkg/versions/_latest | grep -P '(?<=\"name\":\").*?(?=",)' -o`"
		
	let "index++"
done
