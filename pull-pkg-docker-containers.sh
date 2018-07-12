#!/bin/bash
interactive=0
automated=0
help="-i for interactive (specify versions manually)\n-a for automated (expect env vars to be set)"

while getopts ":ia" opt; do
	case ${opt} in
	  i ) interactive=1;;
	  a ) automated=1;;
	  \? ) echo -e $help
	       exit;;
	esac
done

if [ $automated -eq 1 ]; then
	interactive=0
fi

if [[ $interactive == 0 && $automated == 0 ]]; then
	echo -e $help
	exit
fi

if [ $interactive -eq 1 ]; then
	echo -n "tomcat version: "
	read latest_tomcat

	echo -n "mysql version: "
	read latest_mysql

	echo -n "poc version: "
	read latest_poc
fi



if [ $automated -eq 1 ]; then

	vars=("latest_mysql" "latest_tomcat" "latest_poc")
	pkgs=("platform-docker/mysql" "platform-docker/tomcat" "poc-docker/poc")

	index=0
	for pkg in ${pkgs[@]}; do
		echo ${vars[$index]}

		
		eval "${vars[$index]}=`curl https://api.bintray.com/packages/esaude/$pkg/versions/_latest | grep -P '(?<=\"name\":\").*?(?=",)' -o`"
		
		let "index++"
	done
	
	echo "mysql $latest_mysql tomcat $latest_tomcat poc $latest_poc"
fi

#remove old containers
rm common/esaude-p*.tar.gz

sudo docker pull esaude-docker-platform-docker.bintray.io/tomcat:$latest_tomcat
sudo docker pull esaude-docker-platform-docker.bintray.io/mysql:$latest_mysql
sudo docker pull esaude-docker-poc-docker.bintray.io/poc:$latest_poc

sudo docker save esaude-docker-platform-docker.bintray.io/tomcat:$latest_tomcat -o common/esaude-platform-tomcat-docker-${latest_tomcat}.tar
sudo gzip -c9 common/esaude-platform-tomcat-docker-${latest_tomcat}.tar > common/esaude-platform-tomcat-docker-${latest_tomcat}.tar.gz

sudo docker save esaude-docker-platform-docker.bintray.io/mysql:$latest_mysql -o common/esaude-platform-mysql-docker-${latest_mysql}.tar
sudo gzip -c9 common/esaude-platform-mysql-docker-${latest_mysql}.tar > common/esaude-platform-mysql-docker-${latest_mysql}.tar.gz

sudo docker save esaude-docker-poc-docker.bintray.io/poc:$latest_poc -o common/esaude-poc-docker-${latest_poc}.tar
sudo gzip -c9 common/esaude-poc-docker-${latest_poc}.tar > common/esaude-poc-docker-${latest_poc}.tar.gz

#remove uncompressed tape archives
sudo rm common/esaude-p*.tar

sudo chmod 444 common/esaude-p*
