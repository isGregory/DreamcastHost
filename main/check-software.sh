#!/bin/bash
# Script to check that the necessary software is installed,
# if not it will attempt to get it.
#
# Usage:
# check-software.sh $Override
# Where:
# $Override	= The override file
#
# Author: Gregory Hoople
#
# Date Created: 2015-6-11
# Date Modified: 2015-6-11

# Set default variables
# Override File
Override="Override.txt"

echo "Check Software - Recieved: $1"

# Check if arguments have been passed in
# Check for first argument (Override)
if [[ ! -z $1 ]]; then
	Override=$1
fi

# Check if a single package is installed
# $* - Name of the package to look for.
needPackage() {
	toCheck=$*

	# Run dpkg-query on specified package.
 	installedOK=$(dpkg-query -W -f='${Status}' $toCheck)

	if [[ ! $installedOK == *"install ok"* ]]; then
		echo "Need to install $toCheck"
		return 1
	fi

	return 0
}

# Check the necessary packages are installed:
checkInstalled() {

	# Check ppp is installed (for the server)
	needPackage "ppp"
	needPPP=$?

	# Check wvdial is installed (for modem scanning)
	needPackage "wvdial"
	needWVDial=$?

	# Check if the user has stated they don't want to
	# get the apache web server.
	overWeb=$(grep "Webserver Off" $Override | grep -v \#)

	# If they don't state "Webserver Off" we download
	# apache and dnsmasq, otherwise we skip them.
	if [[ -z $overWeb ]]; then
		# Check apache2 is installed (for webserver hosting)
		needPackage "apache2"
		needApache=$?

		# Check dnsmasq is installed (for webserver hosting)
		needPackage "dnsmasq"
		needDNS=$?

		# Check php5-common is installed (for webserver hosting)
		needPackage "php5-common"
		needPHP=$?

		# Check lib-apache2-mod-php5 is installed (for webserver hosting)
		needPackage "libapache2-mod-php5"
		needAP=$?

		# Check php5-cli is installed (for webserver hosting)
		needPackage "php5-cli"
		needPHPcli=$?

		# Check php5-gd is installed (for images on the webserver)
		needPackage "php5-gd"
		needGD=$?
	else
		needApache=0
		needDNS=0
		needPHP=0
		needAP=0
		needPHPcli=0
		needGD=0
	fi

	# If one of the software is not installed
	# we update repositories
	if  [[ $needPPP ]] || [[ $needWVDial ]] || [[ $needApache ]] ||
		[[ $needPHP ]] || [[ $needAP     ]] || [[ $needPHPcli ]] ||
		[[ $needGD  ]] || [[ $needDNS    ]]; then
		return 0
	fi
	return 1
}

# Run the function to check for necessary software
checkInstalled

# Set the return to a variable
hasAllPrograms=$?

if [[ ! $hasAllPrograms ]]; then
	echo "Preparing to Download Software"
	echo "Updating Repositories"
	sudo apt-get update

	# Install ppp if it's not already
	if [[ $needPPP ]]; then
		echo "Installing PPP"
		sudo apt-get install ppp
	fi

	# Install wvdial if it's not already
	if [[ $needWVDial ]]; then
		echo "Installing WVDial"
		sudo apt-get install wvdial
	fi

	# Install apache2 if it's not already
	if [[ $needApache ]]; then
		echo "Installing Apache"
		sudo apt-get install apache2
	fi

	# Install php5-common if it's not already
	if [[ $needPHP ]]; then
		echo "Installing PHP5"
		sudo apt-get install php5-common
	fi

	# Install php5-common if it's not already
	if [[ $needAP ]]; then
		echo "Installing Apache PHP Library"
		sudo apt-get install libapache2-mod-php5
	fi

	# Install php5-common if it's not already
	if [[ $needPHPcli ]]; then
		echo "Installing PHP5-cli"
		sudo apt-get install php5-cli
	fi

	# Install php5-common if it's not already
	if [[ $needGD ]]; then
		echo "Installing PHP5-GD (For Images)"
		sudo apt-get install php5-gd
	fi

	# Install dnsmasq if it's not already
	if [[ $needDNS ]]; then
		echo "Installing dnsmasq"
		sudo apt-get install dnsmasq
	fi


	# Check that after the installing
	# the software is now all there.
	checkInstalled

	# Set the return to a variable
	hasAllPrograms=$?

	# We are missing necessary software,
	# so we quit with an error.
	if [[ ! $hasAllPrograms ]]; then
		echo "Error: Missing necessary software."
		exit 1
	fi
fi

exit 0
