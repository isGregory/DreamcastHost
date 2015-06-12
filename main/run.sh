#!/bin/bash
# Collect settings and send them to sub scripts
#
# Author: Gregory Hoople
#
# Date Created: 2014-8-16
# Date Modified: 2015-6-11

# This function takes in a file address argument,
# checks if the file is exacutable and if not
# attempts to make it so.
# On Failure: Function causes script to exit.
makeExecutable() {
	toCheck=$*

	if [ ! -x $toCheck ]; then
		echo -n "Making $toCheck executable... "
		sudo chmod 755 $toCheck
		if [ ! -x $toCheck ]; then
			echo "FAILED"
			exit
		else
			echo "OK"
		fi
	fi
}

echo "Setting up scripts"

# Define necessary scripts.
scriptSoftware="./check-software.sh"
scriptSettings="./modem-settings.sh"
scriptListener="./modem-listener.sh"
# Note: the load-websites.sh script is
# hard-coded in "modem-settings.sh"
scriptWebsites="./load-websites.sh"

# Make sure necessary scripts are executable.
makeExecutable $scriptSoftware
makeExecutable $scriptSettings
makeExecutable $scriptListener
makeExecutable $scriptWebsites

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
exec sudo $scriptSoftware $Override &

# Wait for the software check to finish executing
wait $!

# If we don't have the necessary software we quit out.
if [[ $? == 1 ]]; then
	exit
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
	exec sudo $scriptSettings $Override $MODEM $DCuser &

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
	exec sudo $scriptListener $Override $MODEM $DCuser &
	wait $!
	echo "Program complete."
fi

# If we skip the "modem-listener.sh", we should get an error statement
# printed out to the user from the "modem-settings.sh" script.
