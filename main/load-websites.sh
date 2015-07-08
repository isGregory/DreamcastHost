#!/bin/bash
# Detect websites to be added to the local server.
# Then install and activate them. This script will
# check the "DIR" directory for acceptable websites.
#
# Usage:
# load-websites.sh
#
# Where "acceptable websites" means:
# Each folder in the "DIR" directory contains three things:
#	 info.txt    - File contains installation information for the website.
#	 site        - File contains apache website settings for the site.
#	 public_html - Directory containing all the website files.
#
# Author: Gregory Hoople
#
# Date Created: 2015-3-28
# Date Modified: 2015-7-7

# Set up variables:

# WEB is the target directory for apache websites.
WEB="/var/www/"

# SET is the target directory for apache settings files.
SET="/etc/apache2/sites-available/"

# DIR is the location this script looks for websites to add.
DIR="add-site"

# The following are the three things
# that every candidate website needs

# OPT specifies the options file name where the target site name is
OPT="info.txt"

# FINDWEB is the directory to move containing all the website files
FINDWEB="public_html"

# FINDSET is the file that will be slightly modified and used for
# the apache settings file.
FINDSET="site"

# The following function goes through and updates
# the server settings based on the related options.
# This function takes two arguments:
# $1 = Directory of website package
# $2 = Website Name
handleSettings() {

	# Define directory argument
	dir=$1

	# Define site name argument
	site=$2

	# Replace settings name with the correct site
	sed -i "s/SITE_NAME/$site/g" $dir$FINDSET

	# Move apache2 settings file
	# ToDo - Check if this fails, if so, don't remove source
	cp $dir$FINDSET $SET$site

	# Tell apache to enable the site
	sudo a2ensite $site

}

# The following function goes through all website
# related options and updates the files.
# This function takes two arguments:
# $1 = Directory of website package
# $2 = Website Name
handleWebsite() {

	# Define directory argument
	dir=$1

	# Define site name argument
	site=$2

	# Check if website folder doesn't already exist
	if [ ! -d "$WEB$site" ]; then

		# Set up the target website folder
		mkdir $WEB$site
	fi

	# Move website folder
	# ToDo - Check if this fails, if so, don't remove source
	cp -r $dir$FINDWEB $WEB$site

	# Set file permissions
	while read -r line; do
		echo "Making $WEB$site/$FINDWEB/$line writable"
		chmod 777 $WEB$site/$FINDWEB/$line

	done < <(grep "Writable" $dir$OPT | grep -v \# |
		awk '{print $2}')
}

# Check to see if any websites are to be uploaded
if [ "$(ls -A $DIR)" ]; then

	# Go through each folder in the target directory
	for d in $DIR/*/ ; do

		if [ ! -d "$d" ]; then
			continue;
		fi

		echo "New website detected: $d"

		# Go through and check that all three of the required
		# files and folders exist in the sub folder.

		echo "Searching for options file: $d$OPT"

		# If the option folder exists
		if [ -f "$d$OPT" ]; then

			echo "Found options file."

			# Check for 'Site' setting in the options file.
			site=$(grep "Site" $d$OPT | grep -v \# | awk '{print $2}')

			# Check for 'Update' setting in the options file.
			update=$(grep "Update" $d$OPT | grep -v \# | awk '{print $2}')

			# Check that the target site has been specified
			if [[ ! -z $site ]]; then
				echo "Site to get: $site"

				# Option to update just the settings file has been detected.
				if [[ $update == "Settings" ]]; then


					# Make sure that the apache settings
					# file is in the target directory
					if [ -f "$d$FINDSET" ]; then

						handleSettings $d $site

						# Remove the original upload folder
						rm -r $d
					else
						echo "Issue moving website. No settings found at $d$FINDSET$site"
					fi

				# Option to update just the website folder has been detected.
				elif [[ $update == "Website" ]]; then

					# Make sure that the target for website
					# files is in the target directory
					if [ -d "$d$FINDWEB" ]; then

						handleWebsite $d $site

						# Remove the original upload folder
						rm -r $d
					else
						echo "Issue moving website. No website files found at $d$FINDWEB"
					fi

				# No specific update option detected, so attempt
				# to update both website and server settings.
				else

					# Make sure that the target for website
					# files is in the target directory
					if [ -d "$d$FINDWEB" ]; then

						# Make sure that the apache settings
						# file is in the target directory
						if [ -f "$d$FINDSET" ]; then

							handleSettings $d $site

							handleWebsite $d $site

							# Remove the original upload folder
							rm -r $d

						else
							echo "Issue moving website. No settings found at $d$FINDSET$site"
						fi
					else
						echo "Issue moving website. No website files found at $d$FINDWEB"
					fi
				fi
			else
				echo "No target website location specified."
			fi
		else
			echo "No options file found."
		fi
	done
else
	echo "No new sites found. $DIR is empty"
fi
