#!/bin/bash
# Collect settings and send them to sub scripts
#
# Author: Gregory Hoople
#
# Date Created: 2014-8-16
# Date Modified: 2015-3-29

echo "Setting up scripts"

# Set up default Override file.
Override="Override.txt"

# Establish Dreamcast User Name
DCuser="dream"

# Check for an 'Override' of 'Login' for User
overUser=$(grep "Login" $Override | grep -v \# | awk '{print $2}')

if [[ ! -z $overUser ]]; then
	DCuser=$overUser
fi

echo "Checking for necessary software"

# Check the necessary packages are installed:
# Check ppp is installed (for the server)
checkPPP=$(dpkg-query -W -f='${Status}' ppp)

# Check wvdial is installed (for modem scanning)
checkWVDial=$(dpkg-query -W -f='${Status}' wvdial)

# Check if the user has stated they don't want to
# get the apache web server.
overWeb=$(grep "Webserver Off" $Override | grep -v \#)

# If they don't state "Webserver Off" we download
# apache and dnsmasq, otherwise we skip them.
if [[ -z $overWeb ]]; then
	# Check apache2 is installed (for webserver hosting)
	checkApache=$(dpkg-query -W -f='${Status}' apache2)

	# Check dnsmasq is installed (for webserver hosting)
	checkDNS=$(dpkg-query -W -f='${Status}' dnsmasq)

	# Check php5-common is installed (for webserver hosting)
	checkPHP=$(dpkg-query -W -f='${Status}' php5-common)

	# Check lib-apache2-mod-php5 is installed (for webserver hosting)
	checkAP=$(dpkg-query -W -f='${Status}' libapache2-mod-php5)

	# Check php5-cli is installed (for webserver hosting)
	checkPHPcli=$(dpkg-query -W -f='${Status}' php5-cli)

	# Check php5-gd is installed (for images on the webserver)
	checkGD=$(dpkg-query -W -f='${Status}' php5-gd)
else
	checkApache=false
	checkDNS=false
fi

# If one of the software is not installed
# we update repositories
if [[ ! $checkPPP    == *"install ok"* ]] ||
   [[ ! $checkWVDial == *"install ok"* ]] ||
   [[ ! $checkApache == *"install ok"* ]] ||
   [[ ! $checkPHP    == *"install ok"* ]] ||
   [[ ! $checkAP     == *"install ok"* ]] ||
   [[ ! $checkPHPcli == *"install ok"* ]] ||
   [[ ! $checkGD     == *"install ok"* ]] ||
   [[ ! $checkDNS    == *"install ok"* ]]; then
	echo "Preparing to Download Software"
	echo "Updating Repositories"
	sudo apt-get update
fi

# Install ppp if it's not already
if [[ ! $checkPPP == *"install ok"* ]]; then
	echo "Installing PPP"
	sudo apt-get install ppp
fi

# Install wvdial if it's not already
if [[ ! $checkWVDial == *"install ok"* ]]; then
	echo "Installing WVDial"
	sudo apt-get install wvdial
fi

# Install apache2 if it's not already
if [[ ! $checkApache == *"install ok"* ]]; then
	echo "Installing Apache"
	sudo apt-get install apache2
fi

# Install php5-common if it's not already
if [[ ! $checkPHP == *"install ok"* ]]; then
	echo "Installing PHP5"
	sudo apt-get install php5-common
fi

# Install php5-common if it's not already
if [[ ! $checkAP == *"install ok"* ]]; then
	echo "Installing Apache PHP Library"
	sudo apt-get install libapache2-mod-php5
fi

# Install php5-common if it's not already
if [[ ! $checkPHPcli == *"install ok"* ]]; then
	echo "Installing PHP5-cli"
	sudo apt-get install php5-cli
fi

# Install php5-common if it's not already
if [[ ! $checkGD == *"install ok"* ]]; then
	echo "Installing PHP5-GD (For Images)"
	sudo apt-get install php5-gd
fi

# Install dnsmasq if it's not already
if [[ ! $checkDNS == *"install ok"* ]]; then
	echo "Installing dnsmasq"
	sudo apt-get install dnsmasq
fi

echo "Checking for Modem"

# Check Overrride file for "Modem"
overModem=$(grep "Modem" $Override | grep -v \# | awk '{print $2}')

# No Override Specified for Dreamcast IP Address
if [[ -z $overModem ]]; then
	# Scan for a modem and get the name of a connected device.
	#
	# Arguments       - Breakdown
	#
	# wvdialconf      - scan for connected modems
	# tr " " "\n"     - 'tr' to replace all spaces with new lines
	# grep "/dev/"    - 'grep' to find a mention of a device
	# cut -d "/" -f 3 - 'cut' out '/dev/' to get just the device's name
	# cut -d "." -f 1 - 'cut' out the trailing period of that line
	MODEM=$(wvdialconf | tr " " "\n" | grep "/dev/" |
		cut -d "/" -f 3 | cut -d "." -f 1 )
else
	echo "Override for Modem Device Found: $overModem"
	MODEM=$overModem
fi

# Check that a modem was found.
if [[ -z $MODEM ]]; then
	echo "Error: No Modem Detected."
	exit
else
	echo "Found Modem: $MODEM"
fi

# Check if the setting turned off writing files
overFile=$(grep "No Files" $Override | grep -v \#)

# If we are writing files
if [[ -z $overFile ]]; then

	echo "Saving Settings Files"

	# Run the script to check for the necessary hardware
	# detect the network settings and create settings files
	exec sudo ./modem-settings.sh $Override $MODEM $DCuser &

	# Wait for the settings to finish executing
	wait $!
else
	# Not writing files
	echo "'No Files' found in Override. Skipping writing settings."
fi

# If we set up the settings successfuly,
# then start the listener
if [[ $? == 0 ]]; then
	echo "Starting Listener"
	exec sudo ./modem-listener.sh $Override $MODEM $DCuser &
	wait $!
	echo "Program complete."
fi

# If we skip the "modem-listener.sh", we should get an error statement
# printed out to the user from the "modem-settings.sh" script.
