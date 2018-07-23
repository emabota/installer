# eSaúde Installation Script

## Overview
A shell script that will help simplify the execution of the [installation](https://docs.google.com/document/d/1KX3cxbw8sBOS9bq-AhP0IV_PDk2xEEZZefb6nD8Svis/edit)/[upgrade](https://docs.google.com/document/d/1otwJrKA9BfmpMqzFlCfem6eajjOirVxjHfs7dlcdgHY/edit) procedures required to get the platform and POC containers installed/upgraded.

This script supports the scenario we imagine to be most likely for the pilot sites (Ubuntu 14.04.4, or 16.04.4, OpenMRS v1.11.5 or v1.11.6, may or may not be using Docker already). Additionally, Ubuntu 18.04 [Bionic](http://releases.ubuntu.com/bionic/) installation is now allowed. Support for other scenarios may be added at a later date.

The installer assumes offline installation/upgrade (without any internet connection), but will allow for the possibility of performing installation/upgrade over the net.

### Usage

Download the [self-extracting installer](https://bintray.com/esaude/installer/installer#files).

Open a terminal and navigate to the directory where the installer was downloaded.

Add the executable permission to the installer:

e.g.
`chmod +x install-esaude-1.2.5.run`

Run the installer:

e.g.
`./install-esaude-1.2.5.run`

The installer will unpack itself in that directory and begin to run.  The installer will require root privileges to perform certain tasks.  You must run the installer as a user who has `sudo` access on the machine and you will be prompted for your password when it is needed.

### Building the Installer Package

Run the following in your cloned version of the repo to build the installer package (you will need the [makeself](https://github.com/megastep/makeself) script installed in your path):

```
./pull-pkg-docker-containers.sh

./download-docker-releases.sh

. ./get-latest-container-ver-num.sh

cd makeself
 
sed install-esaude/install-eSaude.sh "s/__TOMCAT_VERSION__/$latest_tomcat/g; s/__MYSQL_VERSION__/$latest_mysql/g; s/__POC_VERSION__/$latest_poc/g"

./makeself.cmd
```

Note: Please do not add, commit or push an install-eSaude.sh script in which the `__<IMAGE>_VERSION__` placceholders have been replaced. Instead, please make changes to the original, preserving those placeholders, and add, commit and push those changes. Copying the makeself directory to another location outside the repo after changes, before sed replace, may make this process simpler. You may also want to edit the `install-esaude/get_version.sh` file to change the version name of the final executable file.
