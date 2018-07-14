#!/bin/bash

LOG_FILE="log/install-eSaude-`date +'%F_%T'`.log"
exec 3>&1 4>&2 1>${LOG_FILE} 2>&1

if [ "$EUID" -ne 0 ]; then
	printf "\nThis process will require superuser privileges to perform certain tasks.\nPlease enter your password if prompted.\n" | tee /dev/fd/3
fi

if [[ ! $(sudo echo 0) ]]; then
	exit $?
fi

printf "\nA log file will be created to capture the progress of this process.\nThe file will be created in the installer directory with the name:\n${LOG_FILE}\n" | tee /dev/fd/3

double_line="=================================================="
software_name="eSaúde Platform & EMR POC"

. ./get_version.sh

script_version=$installer_version

req_dist_release='Ubuntu 1(8|6|4)\.04(\.[0-9]+)? LTS' 
platform_name_version=`/usr/bin/lsb_release -sd`

dpkg_req_arch='amd64'
dpkg_OS_arch=`dpkg --print-architecture`

req_processor='x86_64'
system_processor=`uname -p`

machine_type=`uname -m`
system_type=`uname -s`

docker_compose_url="https://github.com/docker/compose/releases/download/1.21.0/docker-compose-$system_type-$machine_type"

docker_compose_path='/usr/local/bin/docker-compose'
local_docker_compose_path='common/docker-compose'

new_install=0 # assume upgrade, but allow for new install, if so desired

new_install_confirm_text="Is this a brand new install without an existing copy of OpenMRS running?\nIf so, this process will continue to install the eSaúde Platform without backing up or restoring a database.\nIs that what you want to do? [NO/yes] "

server_alert_text="THIS PROCESS SHOULD ONLY BE RUN ON A DEDICATED UPGRADE SERVER!\nAVOID UPGRADING A LIVE PRODUCTION SERVER AS DATA LOSS MAY OCCUR!\nAre you sure you want to continue? [NO/yes] "

service_alert_text="This process requires shutting down any running services.\nAny users will immediately lose their access and not be able to save or\ncontinue their work.\nAre you sure you want to continue? [NO/yes] "

docker_delete_confirm_text="This process will delete all existing docker containers related to eSaúde.\nAny data that has not been backed up will be lost permanently and forever.\nPlease confirm that you have completed a successful database backup and that you would like to continue with this operation. [NO/yes] "

next_steps_text="The system should now be ready for use.\nIt is important that you login and verify that all the OpenMRS modules are up\nand running.\nIf there isn’t any official information from the eSaúde community stating that\na certain module is susceptible of being stopped/down, please contact the\nUC Global Programs Support Team.\nIf all the modules are up/running, congratulations, you have successfully\ninstalled/upgraded the eSaúde Platform & EMR POC.\nAt this point, if everything above went well, the upgrade was successful. You\ncan proceed with the next steps to deploy the upgraded database on the\nproduction environment."

existing_containers=0 # assume no existing docker containers, but allow for them

ubuntu_codename=`lsb_release -cs`

version_group_regex='[0-9]+'

new_docker_version='18.03.1'
min_docker_version='17.06.0'

#docker_filename="docker-ce_${new_docker_version}_ce-0_ubuntu_amd64.deb"
docker_filename="docker-ce*.deb"

docker_installer=`ls $ubuntu_codename/$docker_filename`

docker_depends_pkgs=(libltdl7 libsystemd-journal0 libseccomp2)

#replace with parsing dpkg -I */docker-ce*.deb?
#dpkg -I $ubuntu_codename/docker-ce* | grep Depends: | sed "s/Depends: //" | grep -P "\(.*?\)" -o | sed "s/(//g; s/)//g; s/>=/ge/g"
#check for each dependency using ver number supplied

trusty_docker_depends_vers=("2.4.2" "201" "0")

recent_docker_depends_vers=("2.4.6" "0" "2.3.0")
xenial_docker_depends_vers=$recent_docker_depends_vers
bionic_docker_depends_vers=$recent_docker_depends_vers

trusty_requires=(1 1 0)
xenial_requires=(1 0 1)
bionic_requires=(1 0 0)

#trusty_docker_depends_pkgs=(libltdl7 libsystemd-journal0)
#xenial_docker_depends_pkgs=(libltdl7 libseccomp2)

docker_depends_dir="./$ubuntu_codename/"

docker_download_url="https://download.docker.com/linux/ubuntu/dists/$ubuntu_codename/pool/stable/amd64/"
docker_download_glob="docker-ce_$new_docker_version*.deb"

min_docker_compose_version='1.12.0'

local_mysqldump_path="./common/mysqldump-5.5.60"

backup_timestamp=`date +'%F_%T'`
omrs_user=""
omrs_pass=""
database_backup="openmrs_backup_${backup_timestamp}.sql"
mysql_pass=""
mysql_db=""

clean_database_script_path="common/clean-database-dump.sh"
cleaned_database_backup="openmrs_backup_${backup_timestamp}_clean.sql"

local_platform_mysql_image="common/esaude-platform-mysql-docker-__MYSQL_VERSION__.tar.gz"
platform_mysql_name="esaude-docker-platform-docker.bintray.io/mysql:__MYSQL_VERSION__"

local_platform_tomcat_image="common/esaude-platform-tomcat-docker-__TOMCAT_VERSION__.tar.gz"
platform_tomcat_name="esaude-docker-platform-docker.bintray.io/tomcat:__TOMCAT_VERSION__"

local_poc_image="common/esaude-poc-docker-__POC_VERSION__.tar.gz"
poc_name="esaude-docker-poc-docker.bintray.io/poc:__POC_VERSION__"

#migrate-to-labels support for upgrading from 1.2 or earlier?

#begin functions
function quit {
	retval=$?
	output "Exiting...\n"
	exit $retval
}

# Output arg to conole and ${LOG_FILE}
function output {
        printf "$1" | tee /dev/fd/3
}

function get_confirmation {

	output "\n$1"

	confirm="no"

	shopt -s nocasematch

	while : ; do

		read confirm

		if [ -z "$confirm" ] || [ "$confirm" != "yes" ]; then
			output "Process canceled by user.\n"
			quit
		else #implies "yes", break psuedo do-while
			break
		fi

	done

}

function checkOS {

	output "\nChecking Linux distribution and release...\n"

	if [[ $platform_name_version =~ $req_dist_release ]]; then
		output "Supported Linux distribution detected: $platform_name_version.\n"
	else
		output "Unsupported Linux distribution detected: $platform_name_version.\n"
		quit
	fi

	output "\nChecking for processor requirements..."
	if [ $system_processor = $req_processor ]; then
		output " 64-bit processor detected.\n"
	else
		output " non 64-bit processor detected.\n"
		quit
	fi

	output "\nChecking for 64-bit OS..."
	if [ $dpkg_OS_arch = $dpkg_req_arch ]; then
		output " 64-bit OS detected.\n"
	else
		output " non 64-bit OS detected.\n"
		quit
	fi
}

function environment_warning {

        get_confirmation "$server_alert_text"

}

function remove_previous_install {

	output "\nLooking for any existing eSaúde Platform container(s)...\n"

	mysql_res=$(sudo docker ps -aq --filter 'name=esaude-platform-mysql' | wc -l)
	if [ $mysql_res -ne 0 ]; then
		mysql_ver=$(sudo docker container inspect esaude-platform-mysql | grep -i '/mysql:' | awk -F ':' '{print $3}' | awk -F '"' '{print $1}')
		output "Platform MySQL container version $mysql_ver found...\n"
	else
		output "Platform MySQL container not found...\n"
	fi

	tomcat_res=$(sudo docker ps -aq --filter 'name=esaude-platform-tomcat' | wc -l)
	if [ $tomcat_res -ne 0 ]; then
		tomcat_ver=$(sudo docker container inspect esaude-platform-tomcat | grep -i '/tomcat:' | awk -F ':' '{print $3}' | awk -F '"' '{print $1}')
		output "Platform Tomcat container version $mysql_ver found...\n"
	else
		output "Platform Tomcat container not found...\n"
	fi

	poc_res=$(sudo docker ps -aq --filter 'name=esaude-emr-poc' | wc -l)
	if [ $poc_res -ne 0 ]; then
		poc_ver=$(sudo docker container inspect esaude-emr-poc | grep -i '/poc:' | awk -F ':' '{print $3}' | awk -F '"' '{print $1}')
		output "eSaúde EMR POC container version $poc_ver found...\n"
	else
		output "eSaúde EMR POC container not found...\n"
	fi

	if [ "$mysql_ver" = "1.4.4" ] || [ "$tomcat_ver" = "1.4.4" ] || [ "$poc_ver" = "2.0.0" ]; then
		output "\nCurrent version(s) of eSaúde Platform container(s) found, possibly from a previous install attempt...\n"
		get_confirmation "Would you like to remove them and re-install? [NO/yes] "
		if [ $mysql_res -ne 0 ]; then
			res=$(sudo docker stop $(sudo docker ps -aq --filter 'name=esaude-platform-mysql') | wc -l)
			if [ $res -ne 0 ]; then
				output "\nStopped Platform MySQL container...\n"
			else
				output "\nFailed to stop Platform MySQL container...\n"
				quit
			fi

			res=$(sudo docker rm $(sudo docker ps -aq --filter 'name=esaude-platform-mysql') | wc -l)
			if [ $res -ne 0 ]; then
				output "Removed Platform MySQL container...\n"
			else
				output "Failed to remove Platform MySQL container...\n"
				quit
			fi
		fi

		if [ $tomcat_res -ne 0 ]; then
			res=$(sudo docker stop $(sudo docker ps -aq --filter 'name=esaude-platform-tomcat') | wc -l)
			if [ $res -ne 0 ]; then
				output "Stopped Platform Tomcat container...\n"
			else
				output "Failed to stop Platform Tomcat container...\n"
				quit
			fi

			res=$(sudo docker rm $(sudo docker ps -aq --filter 'name=esaude-platform-tomcat') | wc -l)
			if [ $res -ne 0 ]; then
				output "Removed Platform Tomcat container...\n"
			else
				output "Failed to remove Platform Tomcat container...\n"
				quit
			fi
		fi

		if [ $poc_res -ne 0 ]; then
			res=$(sudo docker stop $(sudo docker ps -aq --filter 'name=esaude-emr-poc') | wc -l)
			if [ $res -ne 0 ]; then
				output "Stopped EMR POC container...\n"
			else
				output "Failed to stop EMR POC container...\n"
				quit
			fi

			res=$(sudo docker rm $(sudo docker ps -aq --filter 'name=esaude-emr-poc') | wc -l)
			if [ $res -ne 0 ]; then
				output "Removed EMR POC container...\n"
			else
				output "Failed to remove EMR POC container...\n"
				quit
			fi
		fi
	else
		output "\nNo current versions found... continuing...\n"
	fi

}

function locate_tomcat_version {

	tomcat_dirs=()
	count=0

        # check for any existing (and running) Tomcat docker containers
	dpkg_detect_installed docker-ce
	if [ $? -eq 0 ]; then
	        res=$(sudo docker ps -q --filter 'name=esaude-platform-tomcat' | wc -l)
	        if [ $res -ne 0 ]; then
                        existing_containers=1
                        let "count++"
                fi
        fi

        # check for native Tomcat installs
	for f in /var/lib/tomcat*/webapps/openmrs*/WEB-INF; do
		if [ -e "$f" ]; then
                        tomcat_dirs[$count]="$f"
                        let "count++"
                fi
	done

	if [ $count -eq 0 ]; then
		output "\nOpenMRS webapp directory not found...\n"

		get_confirmation "$new_install_confirm_text"

		let "new_install=1"
	elif [ $count -eq 1 ]; then
                if [ $existing_containers -eq 1 ]; then
                        tomcat_version="tomcat7"
                else
		        tomcat_version=`echo $tomcat_dirs[0] | awk -F '/' '{print $4}'`
                fi
        fi

        if [ $count -gt 1 ]; then
		output "\nMultiple OpenMRS webapp directories found, not supported.\n"
		quit
	fi

}

function locate_runtime_props {

	if [ $new_install -eq 1 ]; then
		return 0
	fi

	omrs_app_dir_cmds=()
	count=0
	connection_username_regex="^connection.username\s*="
	connection_password_regex="^connection.password\s*="

        # if existing Tomcat container, count it
	if [ $existing_containers -eq 1 ]; then
                omrs_app_dir_cmds[$count]="sudo docker exec esaude-platform-tomcat cat /usr/local/tomcat/openmrs-runtime.properties"
                let "count++"
        fi

        # check for native OpenMRS installs
	for f in /usr/share/tomcat*/.OpenMRS/*-runtime.properties; do
		if [ -e "$f" ]; then
                        omrs_app_dir_cmds[$count]="sudo cat $f"
                        let "count++"
                fi
	done

	for f in /var/lib/OpenMRS*/*-runtime.properties; do
		if [ -e "$f" ]; then
                        omrs_app_dir_cmds[$count]="sudo cat $f"
                        let "count++"
                fi
	done

	if [ $count -eq 0 ]; then
		output "\nOpenMRS application directory not found...\n"

                get_confirmation "$new_install_confirm_text"

		let "new_install=1"

                return 0
	elif [ $count -eq 1 ]; then
		omrs_runtime_properties_cmd=${omrs_app_dir_cmds[0]}

                # populate $omrs_user and $omrs_pass from native runtime properties file
        	if [ ! -z "$omrs_runtime_properties_cmd" ]; then
        		omrs_user=$(${omrs_runtime_properties_cmd} | grep ${connection_username_regex} | awk -F '=' '{print $2}')
        		omrs_pass=$(${omrs_runtime_properties_cmd} | grep ${connection_password_regex} | awk -F '=' '{print $2}')
        
        		omrs_user=$(echo "$omrs_user" | sed -e 's/'\''/'\''\\'\'''\''/g')
        		omrs_pass=$(echo "$omrs_pass" | sed -e 's/'\''/'\''\\'\'''\''/g')
                fi
        fi

        if [ $count -gt 1 ]; then
		output "\nMultiple OpenMRS application directories found, not supported.\n"
		quit
	fi

}

function stop_services {

	if [ $new_install -eq 1 ]; then
		return 0
	fi

        get_confirmation "$service_alert_text"

	output "\nStopping services..."
	

        if [ $existing_containers -eq 1 ]; then
	        output " stopping Tomcat (container)...\n"

                sudo docker stop esaude-platform-tomcat
        else
	        output " stopping Tomcat...\n"

                sudo service $tomcat_version stop
        fi

}

function get_mysql_root_credentials {

	mysql_pass_regex="\"MYSQL_ROOT_PASSWORD="
	mysql_db_regex="\"MYSQL_DATABASE="

	mysql_pass=$(sudo docker container inspect esaude-platform-mysql | grep -m1 $mysql_pass_regex | awk -F '=' '{print $2}' | awk -F '"' '{print $1}')
	mysql_db=$(sudo docker container inspect esaude-platform-mysql | grep -m1 $mysql_db_regex | awk -F '=' '{print $2}' | awk -F '"' '{print $1}')

}

function backup_database {

	if [ $new_install -eq 1 ]; then
		return 0
	fi

	output "\nAttempting to backup OpenMRS database...\n"

        if [ $existing_containers -eq 1 ]; then
                get_mysql_root_credentials
                eval "sudo docker exec esaude-platform-mysql sh -c 'mysqldump --hex-blob --routines --triggers -uroot -p$mysql_pass --databases $mysql_db > /tmp/dump.sql'"
                eval "sudo docker cp esaude-platform-mysql:/tmp/dump.sql ./$database_backup"
        else
	        if ! hash mysqldump &> /dev/null; then
	        	mysqldump_cmd="$local_mysqldump_path"
	        else
		        mysqldump_cmd="mysqldump"
	        fi

       	        eval "$mysqldump_cmd --hex-blob --routines --triggers -u'$omrs_user' -p'$omrs_pass' --databases openmrs > $database_backup"
        fi

	if [ -s "$database_backup" ]; then
		output "Database backup successful.\nBackup file is located in the installer directory with the name:\n$database_backup\n"
	else
		output "Database backup failed, please review the log file for details: ${LOG_FILE}\n"
		rm $database_backup
       		quit
	fi

}

function clean_backup {

	if [ $new_install -eq 1 ]; then
		return 0
	fi

	if [ -s "$database_backup" ]; then

		if [ -e "$clean_database_script_path" ]; then
			output "\nCleaning database backup..."
			./$clean_database_script_path $database_backup $cleaned_database_backup
			if [ $? -eq 0 ]; then
				output " success...\n"
			else
				output " failed...\n"
				quit
			fi
		else
			output "\nDatabase cleaning script not found...\n"
			quit
		fi
	else
		output "\nDatabase backup file '$database_backup' not found...\n"
		quit
	fi

}

function dpkg_detect_installed {
	dpkg -l $1 | egrep '^(ii|pi) ' -q
}

function find_version {
	eval "$1 | grep '[0-9]*\.[0-9]*\.[0-9]*'"
}

function dpkg_version_installed {
	eval "dpkg -l $1 | egrep '^(ii|pi) ' | grep '[0-9]*\.[0-9]*\.[0-9]' -o | head -1"
}

function compare_versions {
	dpkg --compare-versions $1 ge $2
}

function install_docker {

	#booleans to determine if docker is already up-to-date, needs to be upgraded, or just downloaded and/or installed
	install_docker=1
	upgrading_docker_version=0

	#same for docker_compose
	install_docker_compose=1
	upgrading_docker_compose_version=0

	output "\nChecking for docker...\n"

	dpkg_detect_installed docker 
	if [ $? -eq 0 ]; then
		output "Existing version of docker found... uninstalling...\n"
        	sudo dpkg --purge docker
	fi

	dpkg_detect_installed docker-engine
	if [ $? -eq 0 ]; then
		output "Existing version of docker-engine found... uninstalling...\n"
        	sudo dpkg --purge docker-engine
	fi

	dpkg_detect_installed docker.io
	if [ $? -eq 0 ]; then
		output "Existing version of docker.io found... uninstalling...\n"
        	sudo dpkg --purge docker.io
	fi

	dpkg_detect_installed docker-ce
	if [ $? -eq 0 ]; then
		output "Existing version of docker-ce found... checking version...\n"
		compare_versions $(dpkg_version_installed docker-ce) $min_docker_version
		if [ $? -ne 0 ]; then
			output "Current version incompatible, upgrade required...\n"
			upgrading_docker_version=1
		else	
			output "Current version of docker-ce satisfies requirements...\n"
			install_docker=0
		fi

	else
		output "Docker not found... installing...\n"
		#docker-ce not installed (at least not to dpkg)
	fi

	if [ $install_docker -eq 1 ]; then

		output "\nLooking for docker installer...\n"

		if [ -e "$docker_installer" ]; then
			output "Packaged copy of docker installer found...\n"
		else
			output "Packaged copy of docker installer not found... attempting to download...\n"
			if [ ! -d $ubuntu_codename ]; then
		        	mkdir "$ubuntu_codename"
			fi
			sudo wget -r -l1 -np -nd -P "$ubuntu_codename" "$docker_download_url" --progress=dot -A "$docker_download_glob"

			if [ -s "${docker_installer}" ]; then
				output "Docker installer successfully downloaded...\n"
			else
				output "Docker installer not successfully downloaded...\n"
				quit
			fi
		fi

		package_index=0

		#see tldp.org/LDP/abs/html/ivr.html

		release_req_pkgs="${ubuntu_codename}_requires"
		release_req_vers="${ubuntu_codename}_docker_depends_vers"

		for pkg in ${docker_depends_pkgs[@]};do

			eval "pkg_req=\${$release_req_pkgs[$package_index]}"
			eval "ver_req=\${$release_req_vers[$package_index]}"

			if [ $pkg_req -eq 1 ]; then
				
				output "\nLooking for docker dependency ${pkg}...\n"

				install_pkg=0
				
				dpkg_detect_installed ${pkg}

	               		if [ "$?" -eq 0 ]; then
			                output "Docker dependency already installed... checking version...\n"
			                compare_versions $(dpkg_version_installed ${pkg} ) ${ver_req}
		        	        if [ $? -ne 0 ]; then
			        	        output "Current version incompatible, installing newer version...\n"
                                        	install_pkg=1
		                	else	
			                	output "Current version satisfies requirements...\n"
                               		fi
                        	else
					output "Docker dependency not found... installing...\n"
                               	 	install_pkg=1
                        	fi

				if [ "$install_pkg" -ne 0  ]; then
					
					dep_pkg_filename=`ls ${docker_depends_dir}${pkg}*.deb`
					
					if [ -e "$dep_pkg_filename" ]; then
						output "Packaged copy of docker dependency found...\n"
						sudo dpkg -i $dep_pkg_filename
						dpkg_detect_installed ${pkg}
						if [ $? -eq 0 ]; then
							output "Docker dependency successfully installed...\n"
						else
							output "Docker dependency not successfully installed...\n"
							quit
						fi
					else
						output "Packaged copy of docker dependency not found... attempting to download...\n"
						if [ ! -d $ubuntu_codename ]; then
			        			mkdir $ubuntu_codename
						fi
					
						sudo apt-get -q install ${pkg}
						dpkg_detect_installed ${pkg}
						if [ $? -eq 0 ]; then
							output "Docker dependency successfully installed...\n"
						else
							output "Docker dependency not successfully installed...\n"
							quit
						fi
					fi
				fi
			fi
			let "package_index++"
		done

		sudo dpkg -i $docker_installer
		dpkg_detect_installed docker-ce
		if [ $? -eq 0 ]; then
			output "\nDocker successfully installed...\n"
		else
			output "\nDocker not successfully installed...\n"
			quit
		fi		
	fi

	output "\nChecking for docker-compose...\n"

	if [ -e "$docker_compose_path" ]; then
		output "Existing version of docker-compose found... checking version...\n"
		install_docker_compose=0

		#check version
		docker_compose_version=`sudo $docker_compose_path version --short`
		compare_versions $docker_compose_version $min_docker_compose_version
		#return code is 
		#	1 when left is < right
		#	0 when left is >= right
		if [ $? -eq 1 ]; then
                	output "Current version incompatible, upgrade required...\n"
			upgrading_docker_compose_version=1
		else	
			output "Current version of docker-compose satisfies requirements...\n"
			upgrading_docker_compose_version=0
		fi 
	else
		output "Docker-compose not found... installing...\n"
	fi

	#install docker compose
	if [ $install_docker_compose -eq 1 ] || [ $upgrading_docker_compose_version -eq 1 ]; then 
		
		output "\nLooking for docker-compose...\n"
		if [ ! -e "$local_docker_compose_path" ]; then
			output "Packaged copy of docker-compose not found... attempting to download...\n"
	       		sudo curl -L $docker_compose_url -o $docker_compose_path; sudo chmod +x $docker_compose_path
			if [ -s "${docker_compose_path}" ]; then
				output "Docker-compose successfully downloaded.\n"
			else
				output "Docker-compose not successfully downloaded.\n"
				quit
			fi
		else
			output "Packaged copy of docker-compose found...\n"
			sudo cp $local_docker_compose_path $docker_compose_path
			if [ -s "${docker_compose_path}" ]; then
				output "Docker-compose successfully installed.\n"
			else
				output "Docker-compose not successfully installed.\n"
				quit
			fi		
		fi
	fi

}

function handle_esaude_network {

	# check for existing 'esaude_network' network
	output "\nLooking for docker network 'esaude_network'..."

	res=$(sudo docker network ls | grep -c 'esaude_network')
	if [ $res -eq 0 ]; then
		output " not found... creating...\n"
		res=$(sudo docker network create esaude_network | wc -l)
		if [ $res -eq 0 ]; then
			output "Failed to create docker network...\n"
			quit
		else
			output "Docker network successfully created...\n"
		fi
	else
		output " found... continuing...\n"
	fi

}

function handle_esaude_volume {

	# check for existing 'esaude_data' volume
	output "\nLooking for docker volume 'esaude_data'..."

	res=$(sudo docker volume ls | grep -c 'esaude_data')
	if [ $res -ne 0 ]; then
		output " found... removing...\n"

                get_confirmation "$docker_delete_confirm_text"

		res=$(sudo docker ps -aq --filter 'volume=esaude_data' | wc -l)
		if [ $res -ne 0 ]; then
			output "\nFound $res container(s) using 'esaude_data' volume... removing...\n"

			res=$(sudo docker stop $(sudo docker ps -q --filter 'volume=esaude_data') | wc -l)
			if [ $res -ne 0 ]; then
				output "Stopped $res container(s)...\n"
			else
				output "Failed to stop container(s)...\n"
				quit
			fi

			res=$(sudo docker rm $(sudo docker ps -aq --filter 'volume=esaude_data') | wc -l)
			if [ $res -ne 0 ]; then
				output "Removed $res container(s)...\n"
			else
				output "Failed to remove container(s)...\n"
				quit
			fi

			res=$(sudo docker volume rm esaude_data | wc -l)
			if [ $res -ne 0 ]; then
				output "Docker volume 'esaude_data' removed... re-creating...\n"
			else
				output "Failed to remove 'esaude_data'...\n"
				quit
			fi
		else
			output "\nNo conatiners found using 'esaude_data' volume...\n"
		fi
	else
		output " not found... creating...\n"
	fi

	res=$(sudo docker volume create esaude_data | wc -l)
	if [ $res -eq 0 ]; then
		output "Failed to create docker volume...\n"
		quit
	else
		output "Docker volume successfully created...\n"
	fi

}

function load_new_platform_mysql {

	output "\nLooking for eSaúde Platform MySQL image...\n"

	if [ -s "$local_platform_mysql_image" ]; then
		output "Packaged copy of image found...\n"
		zcat $local_platform_mysql_image | sudo docker image load
	else
		output "Packaged copy of image not found... attempting to download...\n"
		sudo docker pull $platform_mysql_name
	fi

	res=$(sudo docker images -q $platform_mysql_name | wc -l)
	if [ $res -eq 1 ]; then
		output "Image successfully installed...\n"
	else
		output "Image not successfully installed...\n"
		quit
	fi

}

function wait_for_container_start {

	time_passed=0
	start_time=`date +%s`

	output "The current time is `date`, starting container...\n"
	while : ; do
		res=$(sudo docker logs --tail=5 $1 2>&1 | grep -c "$2")

		if [ $res -ne 0 ]; then
			break
		fi
		
                sleep 15
		let "time_passed=`date +%s`-$start_time"

		output "$((time_passed/3600))h$((time_passed%3600/60))m$((time_passed%60))s elapsed    \r"
	done

	output "\n"
}

function start_platform_mysql {

	output "\nStarting eSaúde Platform MySQL container... this may take several minutes...\n"

	sudo docker run --name esaude-platform-mysql -v esaude_data:/opt/esaude/data --network='esaude_network' --restart=unless-stopped -d $platform_mysql_name

	# wait for container to start
        wait_for_container_start esaude-platform-mysql "/usr/sbin/mysqld: ready for connections"

	res=$(sudo docker logs --tail=5 esaude-platform-mysql 2>&1 | grep -c '/usr/sbin/mysqld: ready for connections')
	if [ $res -eq 0 ]; then
		output "eSaúde Platform MySQL container not started...\n"
		quit
	else
		output "eSaúde Platform MySQL container started...\n"
	fi	

}

function restore_database_backup {

	if [ $new_install -eq 1 ]; then
                start_platform_mysql
		return 0
	fi

	output "\nLooking for database backup file..."

	if [ -s "$cleaned_database_backup" ]; then
		output " found, restoring...\n"
                start_platform_mysql
	else
		output " not found, nothing to restore...\n"
		quit
	fi

	output "\nCopying database backup file into container..."

	sudo docker cp ./$cleaned_database_backup esaude-platform-mysql:/tmp/$cleaned_database_backup
	res=$(sudo docker exec esaude-platform-mysql ls -l /tmp/$cleaned_database_backup | wc -l)
	if [ $res -eq 1 ]; then
		output " done...\n"
	else
		output " failed...\n"
		quit
	fi

	output "Restoring from database backup..."

        if [ -z "$mysql_pass" ] || [ -z "$mysql_db" ]; then
                get_mysql_root_credentials
        fi

	sudo docker exec esaude-platform-mysql mysql -uroot -p$mysql_pass $mysql_db -e "drop database openmrs; create database openmrs;"
	eval "sudo docker exec esaude-platform-mysql mysql -uroot -p$mysql_pass $mysql_db -e \"source /tmp/$cleaned_database_backup;\""
	if [ $? -eq 0 ]; then
		output " done...\n"
	else
		output " failed...\n"
		quit
	fi

}

function load_new_platform_tomcat {

	output "\nLooking for eSaúde Platform Tomcat container(s)..."

	res=$(sudo docker ps -aq --filter 'name=esaude-platform-tomcat' | wc -l)
	if [ $res -ne 0 ]; then
		output " found... removing...\n"

		res=$(sudo docker stop $(sudo docker ps -aq --filter 'name=esaude-platform-tomcat') | wc -l)
		if [ $res -ne 0 ]; then
			output "Stopped $res container(s)...\n"
		else
			output "Failed to stop container(s)...\n"
			quit
		fi

		res=$(sudo docker rm $(sudo docker ps -aq --filter 'name=esaude-platform-tomcat') | wc -l)
		if [ $res -ne 0 ]; then
			output "Removed $res container(s)...\n"
		else
			output "Failed to remove container(s)...\n"
			quit
		fi

	else
		output " not found...\n"
	fi

	output "\nLooking for eSaúde Platform Tomcat image...\n"

	if [ -s "$local_platform_tomcat_image" ]; then
		output "Packaged copy of image found...\n"
		zcat $local_platform_tomcat_image | sudo docker image load
	else
		output "Packaged copy of image not found... attempting to download...\n"
		sudo docker pull $platform_tomcat_name
	fi

	res=$(sudo docker images -q $platform_tomcat_name | wc -l)
	if [ $res -eq 1 ]; then
		output "Image successfully installed...\n"
	else
		output "Image not successfully installed...\n"
		quit
	fi

	output "\nStarting eSaúde Platform Tomcat container... this will possibly take 30 minutes or more...\n"

	sudo docker run --name esaude-platform-tomcat -p 8080:8080 -v esaude_data:/opt/esaude/data --network='esaude_network' --restart=unless-stopped -d $platform_tomcat_name

	# wait for container to start
        wait_for_container_start esaude-platform-tomcat "INFO: Server startup in "

	# always needs to be restarted after initial start?
	sleep 10
	sudo docker restart esaude-platform-tomcat
	sleep 20

        wait_for_container_start esaude-platform-tomcat "INFO: Server startup in "

	res=$(sudo docker logs --tail=5 esaude-platform-tomcat 2>&1 | grep -c 'INFO: Server startup in ')
	if [ $res -eq 0 ]; then
		output "eSaúde Platform Tomcat container not started...\n"
		quit
	else
		output "eSaúde Platform Tomcat container started...\n"
	fi	

}

function load_emr_poc {

	output "\nLooking for eSaúde EMR POC container..."

	res=$(sudo docker ps -aq --filter 'name=esaude-emr-poc' | wc -l)
	if [ $res -ne 0 ]; then
		output " found... removing...\n"

		res=$(sudo docker stop $(sudo docker ps -aq --filter 'name=esaude-emr-poc') | wc -l)
		if [ $res -ne 0 ]; then
			output "Stopped $res container(s)...\n"
		else
			output "Failed to stop container(s)...\n"
			quit
		fi

		res=$(sudo docker rm $(sudo docker ps -aq --filter 'name=esaude-emr-poc') | wc -l)
		if [ $res -ne 0 ]; then
			output "Removed $res container(s)...\n"
		else
			output "Failed to remove container(s)...\n"
			quit
		fi

	else
		output " not found...\n"
	fi

	output "\nLooking for eSaúde EMR POC image...\n"

	if [ -s "$local_poc_image" ]; then
		output "Packaged copy of image found...\n"
		zcat $local_poc_image | sudo docker image load
	else
		output "Packaged copy of image not found... attempting to download...\n"
		sudo docker pull $poc_name
	fi

	res=$(sudo docker images -q $poc_name | wc -l)
	if [ $res -eq 1 ]; then
		output "Image successfully installed...\n"
	else
		output "Image not successfully installed...\n"
		quit
	fi

	output "\nStarting eSaúde EMR POC container... this may take several minutes...\n"

	sudo docker run --name esaude-emr-poc -p 80:80 --network='esaude_network' --link=esaude-platform-tomcat --restart=unless-stopped -d $poc_name

	# wait for container to start
        wait_for_container_start esaude-emr-poc "httpd -D FOREGROUND"

	res=$(sudo docker logs --tail=5 esaude-emr-poc 2>&1 | grep -c 'httpd -D FOREGROUND')
	if [ $res -eq 0 ]; then
		output "eSaúde EMR POC container not started...\n"
		quit
	else
		output "eSaúde EMR POC container started...\n"
	fi	

}

function instruct_next_steps {

        output "\n$next_steps_text\n"

}

function main {

	output "\n$double_line\n$software_name Installer v$script_version\n$double_line\n"

	checkOS

	environment_warning

	remove_previous_install

	locate_tomcat_version

	locate_runtime_props

	stop_services

	backup_database

	clean_backup

	install_docker

	if [ $install_docker -eq 1 ] || [ $upgrading_docker_version -eq 1 ] || [ $install_docker_compose -eq 1 ] || [ $upgrading_docker_compose_version -eq 1 ]; then 
        	output "\nVerifying docker/docker-compose installation/upgrade...\n"
        	install_docker
	fi

	handle_esaude_network

	handle_esaude_volume

	load_new_platform_mysql

	restore_database_backup

	load_new_platform_tomcat

        load_emr_poc

	instruct_next_steps

	output "\nProcess completed.\nPlease review the log file in the installer directory for details:\n${LOG_FILE}\n"

}

main
