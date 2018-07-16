#!/bin/bash

vars=("latest_mysql" "latest_tomcat" "latest_poc")
pkgs=("platform-docker/mysql" "platform-docker/tomcat" "poc-docker/poc")

index=0
for pkg in ${pkgs[@]}; do
	#echo ${vars[$index]}

	if [ -z "$FORCE_BUILD" ] || [ "$FORCE_BUILD" == 0 ]; then	
		eval "${vars[$index]}=`curl https://api.bintray.com/packages/esaude/$pkg/versions/_latest | grep -P '(?<=\"name\":\").*?(?=",)' -o`"
	else
		eval "tmp_var=\$${vars[$index]}"
		echo "using exisiting environment variable \$${vars[$index]}=$tmp_var"
	fi
	let "index++"
done
