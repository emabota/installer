# eSaúde Installation Script

## Overview
A shell script that will help simplify the execution of the [installation](https://docs.google.com/document/d/1KX3cxbw8sBOS9bq-AhP0IV_PDk2xEEZZefb6nD8Svis/edit)/[upgrade](https://docs.google.com/document/d/1otwJrKA9BfmpMqzFlCfem6eajjOirVxjHfs7dlcdgHY/edit) procedures required to get the platform and POC containers installed/upgraded.

Initially, this script will support the scenario we imagine to be most likely for the pilot sites (Ubuntu 14.04.4 or 16.04.4, OpenMRS v1.11.5 or v1.11.6, may or may not be using Docker already).  Support for other scenarios will be added at a later date.

The installer assumes offline installation/upgrade (without any internet connection), but will allow for the possibility of performing installation/upgrade over the net.

### Usage

Download the [self-extracting installer](https://gitlab.cirg.washington.edu/esaude/install-script/blob/master/makeself/install-esaude-1.0.0-beta.1.run).

Open a terminal and navigate to the directory where the installer was downloaded.

Add the executable permission to the installer:

`chmod +x install-esaude-1.0.0-beta.1.run`

Run the installer:

`./install-esaude-1.0.0-beta.1.run`

The installer will unpack itself in that directory and begin to run.  The installer will require root privileges to perform certain tasks.  You must run the installer as a user who has `sudo` access on the machine and you will be prompted for your password when it is needed.

### Building the Installer Package

Run the following in your cloned version of the repo to build the installer package (you will need the [makeself](https://github.com/megastep/makeself) script installed in your path):

`cd makeself`

`./makeself.cmd`

Note: You may first want to edit the `makeself.cmd` file to change the name of the final executable file.
