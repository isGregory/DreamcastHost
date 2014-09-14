#!/bin/bash
# Collect settings and send them to sub scripts
#
#
# Author: Gregory Hoople
#
# Date Created: 2014-8-16
# Date Modified: 2014-9-13

echo "Setting up scripts"

# Set up default Override file.
Override="Override"

# Establish Dreamcast User Name
DCuser="dream"

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
else
	checkApache="Skip"
	checkDNS="Skip"
fi

# If one of the software is not installed
# we update repositories
if [[ -z $checkPPP ]] || [[ -z $checkWVDial ]] ||
	[[ -z $checkApache ]] || [[ -z $checkDNS ]]; then
	echo Preparing to Download Software
	echo Updating Repositories
	sudo apt-get update
fi

# Install ppp if it's not already
if [[ -z $checkPPP ]]; then
	echo Installing PPP
	sudo apt-get install ppp
fi

# Install wvdial if it's not already
if [[ -z $checkWVDial ]]; then
	echo Installing WVDial
	sudo apt-get install wvdial
fi

# Install apache2 if it's not already
if [[ -z $checkApache ]]; then
	echo Installing Apache
	sudo apt-get install apache2
fi

# Install dnsmasq if it's not already
if [[ -z $checkDNS ]]; then
	echo Installing dnsmasq
	sudo apt-get install dnsmasq
fi

echo "Checking for Modem"

# Check Overrride file for "Modem"
overModem=$(grep "Modem" $Override | grep -v \# |
	cut -d ":" -f 2 | cut -d " " -f 2)

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
	echo Error: No Modem Detected.
	exit
else
	echo Found Modem: $MODEM
fi

echo "Saving Settings Files"
# Run the script to check for the necessary hardware
# detect the network settings and create settings files
exec sudo ./modem-settings.sh $Override $MODEM $DCuser &

# Wait for the settings to finish executing
wait

# If we set up the settings successfuly,
# then start the listener
if [[ $? == 0 ]]; then
	echo "Starting Listener"
	exec sudo ./modem-listener.sh $Override $MODEM $DCuser &
	wait
	echo "Program complete."
fi



#echo "Updating Settings:"
##setup=$(exec sudo ./modem-settings.sh) &
#grabStuff=""
#exec 4>&1
#grabStuff=$(exec sudo ./modem-settings.sh | tee /dev/fd/4)
#wait
#echo "$grabStuff" | grep "Found Modem:"
#echo "Settings up to date. Running listener:"
##exec sudo ./modem-listener.sh &
#wait
#echo "Program complete."
