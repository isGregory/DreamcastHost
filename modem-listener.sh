#!/bin/bash
# Test modem stuff
# Code for communication with the modem was
# based on information posted by pabouk on
# www.askubuntu.com/questions/323352
#
# Usage:
# modem-listener.sh $Override $Modem $DCuser
# Where:
# $Override	= The override file
# $Modem	= Modem device to use
# $DCuser	= User account to connect to
#
# Author: Gregory Hoople
#
# Date Created: 2014-8-6
# Date Modified: 2014-9-13

# Variable to keep track of
# where to save the logfile.
LOGFILE=Demo/modemlog

# How long to sleep between
# checks in the main loop.
INTERVAL=1

# Keeps track of voice mode
VCLASS=8

# Variable keeps track of what
# voice mode listens to the line.
VPHONE=1

# There are two main types of modem commands.
# Here one can change it from "+" commands to
# "#" commands.
mType="+" #or set as "#"

# Track the state of the dialtone detection
DIALTONE=0

# Set Communication Speed
SPEED=115200

# Checks the level of log output
overShow=""

# Set default variables
# Override File
Override="Override"

# Modem device to connect to
MODEM="/dev/ttyACM0"

# User to log in as
DCuser="dream"

echo "Recieved: $1 | $2 | $3"

# Check if arguments have been passed in
# Check for first argument (Override)
if [[ ! -z $1 ]]; then
	Override=$1
fi

# Check for second argument (Modem)
if [[ ! -z $2 ]]; then
	MODEM="/dev/$2"
fi

# Check for third argument (User Name)
if [[ ! -z $3 ]]; then
	DCuser=$3
fi


# Set up Listening Mode Variables
# 'Enter' listens for 'Enter' key press to answer
Enter=0
# 'Tones' listens to dialing digits to answer
Tones=1
ListenMode=$Enter

# Message Formatting:
LOGDATE="date +%Y-%m-%d-T%H:%M:%S"
SYS="* System: "
REP="<-- Back: "
SND="--> Sent: "

# Clear out the Log File for the new run
echo "$($LOGDATE) Program Begins" > "$LOGFILE"

# log message to a logfile and a terminal
log() {
	echo "$($LOGDATE) $@" >> "$LOGFILE"
	echo "$($LOGDATE) $@"
}

# Prints out a log message, but lacks a newline
# This is used for the user input on pressing
# "Enter" only to make things look cleaner.
logNL() {
	echo "$($LOGDATE) $@" >> "$LOGFILE"
	echo -n "$($LOGDATE) $@"
}

# Start the log and set up the final entry with "trap"
trap 'log "===== LOGGER STOPPED: $BASHPID ====="' EXIT

log       "===== LOGGER STARTED: $BASHPID ====="

# Initial modem setup and establishment of streams
# to and from the modem.
setup(){
	log "$SYS Setting Up Modem"
	stty -F $MODEM sane
	stty -F $MODEM $SPEED -echo igncr icanon onlcr

	# Set up stream from the modem
	exec 5<$MODEM

	# Set up stream to the modem
	exec 6>$MODEM

	log "$SYS Modem Set Up"
}

# Run the "setup" command.
setup

# Set the program to close streams on exit.
trap 'exec 5<&-' EXIT
trap 'exec 6>&-' EXIT

# Check if we're showing everything received:
overShow=$(grep "Show All" $Override | grep -v \#)

# Note:
# With DTMF tones (Read: Phone Key Presses) a character
# of integer value 16 comes in before the number that
# was dialed (To signal that it was of importance)
DTMFflag=$(printf "\x$(printf %x 16)")

# Note:
# The modem returns information that doesn't
# make it past the following type of if statement
#	if [[ -z $REPLY ]]; then
# however these same groups of information have
# character information that is accepted by
#	if (( ${#REPLY} > 0 )); then
# Which is why the second one, which counts
# string length is used over "-z".


# Write Command to modem
wrmodem() {
	# Writes command to output stream
	echo "$*" >&6

	# Here we check if what we were sending
	# has any length, and if so we log it.
	toSend=$*
	if (( ${#toSend} > 0 )); then
		log "$SND $*"
	fi
}

# Read until buffer is empty
clearBuff() {
	# Establish the max emtpy chain
	maxEmpty=3

	# Keep track of the empty responses
	curEmpty=0

	# Read back the command, if the lines
	# have characters, we log them.
	while [[ $curEmpty < $maxEmpty ]]; do
		read -t 1 BACK <&5
		if (( ${#BACK} > 0 )); then
			log "$REP $BACK"
			curEmpty=0
		else
			curEmpty=$(($curEmpty + 1))
		fi
	done
}

# Check that the modem has the ability to use voice
# and check for which voice command to use if so.
# Otherwise we alert the user and exit the program.
# This request can be very buggy, and the responses
# can be very inconsistant. So we have to be
# careful how we handle it. That's why the program
# really takes its time getting all the data. Even
# with going slow, there are times where the modem
# doesn't respond in time.
log "$SYS Checking for Listening Mode"

# Request the FCLASS abilities of this modem
# Responses list all the different modem
# specifications this modem can preform.
#
# Modes:	Description:
# 1		Data Mode
# 2		Fax
# 8		Voice
#
# Voice allows us to listen for phone key presses.
if [[ $mType == "#" ]]; then
	wrmodem "AT#CLS=?"
else
	wrmodem "AT+FCLASS=?"
fi

# We wait a second to allow the response to come back
sleep 1

# We then read a series of responses. This command
# generally returns 3-4 lines, but we need a few
# additional lines incase something goes wrong
# or if additional data is in the pipeline.
# So we keep reading until we get 5 empty returns
# in a row.
maxEmpty=5
curEmpty=0
while [[ $curEmpty < $maxEmpty ]]; do
#for i in {1..10}; do

	# Read from the stream
	read -t 1 BACK <&5

	# If the read has some characters
	# in it, then we log it.
	if (( ${#BACK} > 0 )); then
		log "$REP $BACK"
		curEmpty=0
	else
		curEmpty=$(($curEmpty + 1))
	fi

	# If the read has information that says
	# this modem has voice mode, then we
	# set the ListenMode to tones.
	if [[ $BACK == *",8"* ]]; then
		log "$SYS Listening Mode Available"
		ListenMode=$Tones
	fi
done

# If this modem supports voice mode, and can
# thus listen to tones, we need to check what
# Voice Mode takes the phone off the hook.
# The issue is there's no standard here for
# the number companies need to use. So
# instead we need to look for the number
# associated with the mode "T".
if [[ $ListenMode == $Tones ]]; then

	log "$SYS Setting Modem to Listen"

	# First put the modem into voice mode
	# If we don't do this, the "VLS" command
	# may return "ERROR"
	if [[ $mType == "#" ]]; then
		wrmodem "AT#CLS=8"
	else
		wrmodem "AT+FCLASS=8"
	fi

	# Wait a second for the modem to respond.
	sleep 1

	# Clear the buffer
	clearBuff

	log "$SYS Checking for 'Line' Mode"

	# Here we request from the modem the
	# different voice modes it can support
	if [[ $mType == "#" ]]; then
		wrmodem "AT#VLS=?"
	else
		wrmodem "AT+VLS=?"
	fi

	# Wait a second for the modem to respond.
	sleep 1

	# Establish the max emtpy chain
	maxEmpty=3

	# Keep track of the empty responses
	curEmpty=0

	# Some modems have 10+ voice modes they
	# can support. So we keep reading in
	# until we get 5 empty returns in a row.
	while [[ $curEmpty < $maxEmpty ]]; do
		read -t 1 BACK <&5
		if (( ${#BACK} > 0 )); then
			log "$REP $BACK"
			curEmpty=0
		else
			curEmpty=$(($curEmpty + 1))
		fi

		# Here we're checking if this line
		# specifies the "T" mode, which is
		# just the modem listening to the
		# phone line. Once that's found
		# we set the "VPHONE" variable to it
		if [[ $BACK == *"\"T\""* ]]; then
			VPHONE=$(echo $BACK | awk -F "," '{print $1}')
			log "$SYS 'Line' Mode Found: $VPHONE"
		fi

		# After finding the mode we have to
		# continue to read through the loop
		# in order to clear out the stream.
	done
fi
#ListenMode=$Enter

# Read Information from modem
readReply() {

#	wrmodem "AT+VTS=5,255"

	# Read from the stream
	read -t 1 REPLY <&5

	# Check that this string has
	# a length greater than 0.
	if (( ${#REPLY} > 0 )); then

		# Replace the DTMFflag with '#'
		# so it's easier to read.
		OUTPUT=$(echo $REPLY | tr $DTMFflag \#)

		# If we hear a dial tone, alert the user of change
		if [[ $OUTPUT == *#d* ]]; then
			if [[ $DIALTONE == 0 ]]; then
				log "$SYS Dial Tone Detected"
				DIALTONE=1

			fi
		else
			if [[ $DIALTONE == 1 ]]; then
				log "$SYS Dial Tone Lost"
				DIALTONE=0
			fi
		fi

		# Check if we're filtering the output or not.
		if [[ -z $overShow ]]; then

			# Filter out dial tone indications.
			OUTPUT=$(echo $OUTPUT | sed "s/#d//g")

			if (( ${#OUTPUT} > 0 )); then
				# Only output responses when they
				# are indicating something beyond
				# what was filtered out.
				log "$REP $OUTPUT"
			fi
		else
			# Output after only filtering the
			# special character.
			log "$REP $OUTPUT"
		fi

		# If we can't connect, go back to listening
		# This is looking for "NO CARRIER". Though
		# there's a chance the modem could drop a
		# character in transmition. So we check
		# for a middle section just incase.
		if [[ $REPLY == *"O CAR"* ]]; then

			# Check the mode we're in.
			# and if we're listening for
			# dialing tones or an enter
			if [[ $ListenMode == $Tones ]]; then
				listen
			else
				listenEnter
			fi
		fi

		# If we hear a phone key press, answer the line
		if [[ $REPLY == *$DTMFflag[0-9]* ]]; then
			answer
		fi

		# If we have connected then start up the server
		# This is looking for "CONNECT". Though
		# there's a chance the modem could drop a
		# character in transmition. So we check
		# for a middle section just incase.
		if [[ $REPLY == *"ONNEC"* ]]; then
			log "$SYS Starting PPPD server"

			# Start PPP to handle the current connection
			pon $DCuser

			#Needed?
			sleep 5

			# Release the streams to the modem
			exec 5<&-
			exec 6>&-

			log "$SYS Conection Established. (Waiting for PPPD to exit)"
			# This is a while loop that keeps checking if
			# PPPD is still running. Once it stops running
			# we exit the loop.
			while true; do
				running=$(ps cax | grep pppd)
				if [[ -z $running ]]; then
					break;
				fi
				sleep 1
			done
			log "$SYS Connection Lost. (PPPD has exited)"
			REPLY=""

			# Reconnect to the modem
			setup

			# Set the modem into listening mode
			# Check the mode we're in.
			# and if we're listening for
			# dialing tones or an enter
			if [[ $ListenMode == $Tones ]]; then
				listen
			else
				listenEnter
			fi
		fi
	fi
}

# Set modem into voice mode to listen for digits
listen() {
	log "=== START LISTENING PROCEDURE ==="
	# AT		- Call modem to attention
	# &F0		- Reset modem to defaults
	# +FCLASS=8	- Set the modem into voice mode
	#
	# Note: This command may return an error if
	# "AT+FCLASS=?" is called before, as that
	# command can put the modem into voice mode.
	# The error, in that case, does not cause
	# any issues to functions we wish to run.
	if [[ $mType == "#" ]]; then
		wrmodem "AT&F0#CLS=$VCLASS"
	else
		wrmodem "AT&F0+FCLASS=$VCLASS"
	fi
	sleep 1

	# Set modem to listen to phone line
	if [[ $mType == "#" ]]; then
		wrmodem "AT#VLS=$VPHONE"
	else
		wrmodem "AT+VLS=$VPHONE"
	fi
	sleep 1

	# Clear the reply buffer
	clearBuff

	log "$SYS Listening for Dialing Keys"
}

# Modem doesn't seem to support a voice mode
# and thus can't read DTMF (Dialing) tones
# so the program now waits for an enter key
# to activate the answer procedure and take
# care of the rest for them
listenEnter() {
	log "=== START LISTENING PROCEDURE ==="

	logNL "$SYS Press [Enter] to Answer"

	# Wait for [Enter]
	read Call

	# Start the Answering Procedure
	answer

}

# Set modem into data mode to answer calls
answer() {
	log "=== START ANSWERING PROCEDURE ==="
	# Hangup the phoneline
	wrmodem "ATH"
	sleep 1

	# AT		- Call modem to attention
	# &F0		- Reset modem to defaults
	# &R0		- Tell modem to ignore calls from terminal
	#			( This prevents the modem from halting	)
	#			(  an action in order to listen to the	)
	#			( program. This is expecially helpful	)
	#			( to prevent the modem from prematurely	)
	#			( ending the answer procedure.		)
	# +FCLASS=0	- Set the modem into data mode
	if [[ $mType == "#" ]]; then
		wrmodem "AT&F0&R0#CLS=0"
	else
		wrmodem "AT&F0&R0+FCLASS=0"
	fi
	sleep 1

	clearBuff

	# Answer the phoneline
	wrmodem "ATA"
	log "$SYS Negotiating Connection"
}

# Set the modem into listening mode
# Check the mode we're in.
# and if we're listening for
# dialing tones or an enter
if [[ $ListenMode == $Tones ]]; then
	listen
else
	listenEnter
fi

# Main Loop
while true; do
	wrmodem ""
	readReply
	readReply
	sleep $INTERVAL
done
