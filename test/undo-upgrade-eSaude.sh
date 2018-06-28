#!/bin/bash

LOG_FILE="undo-upgrade-eSaude-`date +'%F_%T'`.log"
exec 3>&1 4>&2 1>${LOG_FILE} 2>&1

if [ "$UID" -ne 0 ]; then
	printf "\nThis process will require superuser privileges to perform certain tasks.\nPlease enter your password when prompted.\n" | tee /dev/fd/3
fi

if [[ ! $(sudo echo 0) ]]; then
	exit $?
fi

dpkg_req_arch='amd64'
dpkg_OS_arch=`dpkg --print-architecture`

req_processor='x86_64'
system_processor=`uname -p`

machine_type=`uname -m`
system_type=`uname -s`

docker_compose_path='/usr/local/bin/docker-compose'

ubuntu_codename=`lsb_release -cs`

new_docker_version='18.03.1'

platform_mysql_name="esaude-docker-platform-docker.bintray.io/mysql:1.4.4"

platform_tomcat_name="esaude-docker-platform-docker.bintray.io/tomcat:1.4.4"

poc_name="esaude-docker-poc-docker.bintray.io/poc:2.0.0"

#begin functions
function quit {
	retval=$?
	output "Exiting...\n"
	exit $retval
}

# Output first arg to console and ${LOG_FILE}
function output {
	printf "$1" | tee /dev/fd/3
}

function dpkg_detect_installed {
        dpkg -l $1 | grep '^ii ' -q
}

function uninstall_docker_artifacts {

	sudo docker stop $(sudo docker ps -q --filter 'network=esaude_network')

	sudo docker rm $(sudo docker ps -aq --filter 'network=esaude_network')

	sudo docker stop $(sudo docker ps -q --filter 'volume=esaude_data')

	sudo docker rm $(sudo docker ps -aq --filter 'volume=esaude_data')

	sudo docker network rm esaude_network

	sudo docker volume rm esaude_data

	sudo docker image rm $poc_name $platform_mysql_name $platform_tomcat_name

}

function uninstall_docker {

	output "\nChecking for docker...\n"

	dpkg_detect_installed docker-ce
	if [ $? -eq 0 ]; then
		output "Previous version of docker-ce found... uninstalling...\n"
		sudo dpkg --purge docker-ce
	else
		output "Docker not found.\n"
	fi

	output "\nChecking for docker-compose...\n"

	if [ -e $docker_compose_path ]; then
		output "Previous version of docker-compose found... uninstalling...\n"
		sudo rm -f $docker_compose_path
	else
		output "Docker-compose not found.\n"
	fi

}

function main {

output "\nUndoing install/upgrade of eSaúde Platform & POC...\n"

uninstall_docker_artifacts

uninstall_docker

}

main
