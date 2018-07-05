#!/bin/bash
interactive=0
automated=0
slow_latest=0
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

	if [ -z $latest_tomcat ]; then
		echo -e "\$latest_tomcat is not set.\nIt should be a version number used by the artifactory e.g. 1.4.5"
	exit_script=""
	fi
	if [ -z $latest_mysql ]; then
		echo -e "\$latest_mysql is not set.\nIt should be a version number used by the artifactory e.g. 1.4.5"
	exit_script=""
	fi
	if [ -z $latest_poc ]; then
		echo -e "\$latest_poc is not set.\nIt should be a version number used by the artifactory e.g. 2.0.2"
	exit_script=""
	fi

if [ -e $exit_script ]; then
	exit 255
fi

fi

if [ $slow_latest -eq 1 ]; then
	
	#probably the slowest way to find out the most recent version, but the most immediately implementable. there are no "latest" tags? seems like that would be much faster and easier, need to find out why there aren't...
	sudo docker pull -a esaude-docker-platform-docker.bintray.io/tomcat
	sudo docker pull -a esaude-docker-platform-docker.bintray.io/mysql
	sudo docker pull -a esaude-docker-poc-docker.bintray.io/poc

	latest_tomcat=sudo docker images esaude-docker-platform-docker.bintray.io/tomcat --format "{{.Tag}}" | sort -Vr | head -n 1
	
	latest_mysql=sudo docker images esaude-docker-platform-docker.bintray.io/mysql --format "{{.Tag}}" | sort -Vr | head -n 1
	
	latest_poc=sudo docker images esaude-docker-poc-docker.bintray.io/poc --format "{{.Tag}}" | sort -Vr | head -n 1
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
