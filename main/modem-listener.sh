#!/bin/bash
# This is a script which is used to listen and
# establish a connection with a dreamcast by
# either listening for the dreamcast to dial in
# or for the user to tell the script to answer.
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
# Date Modified: 2015-4-4
#
# Code for communication with the modem was
# based on information posted by pabouk on
# www.askubuntu.com/questions/323352

# Variable to keep track of
# where to save the logfile.
LOGFILE="logs/modemlog.txt"

# Variable keeps track of which
# voice mode listens to the line.
vPhone=1

# There are two main types of modem commands.
# Here one can change it from "+" commands to
# "#" commands.
mType="+" #or set as "#"

# Set the maximum number of empty responses
# to wait around for before assuming the
# responses from the modem are all collected.
MAXEMPTY=2

# Set Communication Speed
SPEED=115200

# Track the state of the dialtone detection
dialTone=0

# Set default variables
# Override File
Override="Override.txt"

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
# Default the mode to Enter.
ListenMode=$Enter

# Check if we're showing everything sent and received:
overShow=$(grep "Show All" $Override | grep -v \#)

# Check if the user wants things to go slower
# to give more time for the modem to respond.
overFast=$(grep "Slow" $Override | grep -v \#)

if [[ -z $overFast ]]; then
	INTERVAL=0
else
	INTERVAL=1
fi

# Note:
# With DTMF tones (Read: Phone Key Presses) a character
# of integer value 16 comes in before the number that
# was dialed (To signal that it was of importance)
DTMFflag=$(printf "\x$(printf %x 16)")

# Message Formatting:
LOGDATE="date +%Y-%m-%d-T%H:%M:%S"
SYS="* System: "
REP="<-- Back: "
SND="--> Sent: "

# Clear out the Log File for the new run
echo "$($LOGDATE) Program Begins" > "$LOGFILE"

# This function is used to give the modem extra
# time to respond should the user define it.
breath() {
	if [[ $INTERVAL > 0 ]]; then
		sleep $INTERVAL
	fi
}

# log message just to logfile
logDOC() {
	echo "$($LOGDATE) $@" >> "$LOGFILE"
}

# log message to a logfile and a terminal
log() {
	logDOC "$@"
	echo "$($LOGDATE) $@"
}

# log program message
logSYS() {
	log "$SYS $@"
}

# log response message
logREP() {
	# Don't share these messages with the user
	# unless they ask to see everything.
	if [[ ! -z $overShow ]]; then
		log "$REP $@"
	else
		logDOC "$REP $@"
	fi
}

# log sent message
logSND() {
	# Don't share these messages with the user
	# unless they ask to see everything.
	if [[ ! -z $overShow ]]; then
		log "$SND $@"
	else
		logDOC "$SND $@"
	fi
}

# Prints out a log message, but lacks a newline
# This is used for the user input on pressing
# "Enter" only to make things look cleaner.
logNL() {
	echo "$($LOGDATE) $@" >> "$LOGFILE"
	echo -n "$($LOGDATE) $@"
}

# Initial modem setup and establishment of streams
# to and from the modem.
setup() {
	logSYS "Setting Up Modem"
	stty -F $MODEM sane
	stty -F $MODEM $SPEED -echo igncr icanon onlcr

	# Set up stream from the modem
	exec 5<$MODEM

	# Set up stream to the modem
	exec 6>$MODEM

	logSYS "Modem Set Up"
}

# Write Command to modem
# Note:
# The modem returns information that doesn't
# make it past the following type of if statement
#	"if [[ -z $REPLY ]]; then"
# however these same groups of information have
# character information that is accepted by
#	"if (( ${#REPLY} > 0 )); then"
# Which is why the second one, which counts
# string length is used over "-z".
wrmodem() {
	# Writes command to output stream
	echo "$*" >&6

	# Here we check if what we were sending
	# has any length, and if so we log it.
	toSend=$*
	if (( ${#toSend} > 0 )); then
		logSND "$*"
	fi
}

# Filters the formatting of a modem reply
# so that it is cleaner to read.
filterReply() {

	# Replace the DTMFflag with '#'
	# so it's easier to read.
	output=$(echo $@ | tr $DTMFflag \#)

	# If we hear a dial tone, alert the user of change
	if [[ $output == *#d* ]]; then
		if [[ $dialTone == 0 ]]; then
			logSYS "Dial Tone Detected"
			dialTone=1

		fi
	else
		if [[ $dialTone == 1 ]]; then
			logSYS "Dial Tone Lost"
			dialTone=0
		fi
	fi

	# Filter out dial tone indications.
	output=$(echo $output | sed "s/#d//g")

	if (( ${#output} > 0 )); then
		# Only output responses when they
		# are indicating something beyond
		# what was filtered out.
		logREP "$output"
	fi
}

# Read until buffer is empty
emptyBuff() {

	# Keep track of the empty responses
	curEmpty=0

	# Read back the command, if the lines
	# have characters, we log them.
	while [[ $curEmpty < $MAXEMPTY ]]; do
		read -t 1 BACK <&5
		if (( ${#BACK} > 0 )); then
			filterReply $BACK
			curEmpty=0
		else
			curEmpty=$(($curEmpty + 1))
		fi
	done
}

# Read Information from modem
readReply() {

	# Read input
	REPLY=$@
	filterReply $REPLY

	# If we have connected then start up the server
	# This is looking for "CONNECT". Though
	# there's a chance the modem could drop a
	# character in transmition. So we check
	# for a middle section just incase.
	if [[ $REPLY == *"ONNEC"* ]]; then
		logSYS "Starting PPPD server"

		# Start PPP to handle the current connection
		pon $DCuser

		# Release the streams to the modem
		exec 5<&-
		exec 6>&-

		logSYS "Conection Established. (Waiting for PPPD to exit)"
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
		logSYS "Connection Lost. (PPPD has exited)"
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

	# If we can't connect, go back to listening
	# This is looking for "NO CARRIER". Though
	# there's a chance the modem could drop a
	# character in transmition. So we check
	# for a middle section just incase.
	elif [[ $REPLY == *"O CAR"* ]]; then

		logSYS "Connection Attempt Failed."

		# Check the mode we're in.
		# and if we're listening for
		# dialing tones or an enter
		if [[ $ListenMode == $Tones ]]; then
			listen
		else
			listenEnter
		fi

	# If we hear a phone key press, answer the line
	elif [[ $REPLY == *$DTMFflag[0-9]* ]]; then
		answer
	fi
}

# Read until buffer is empty
readBuff() {

	# Keep track of the empty responses
	curEmpty=0

	# Read back the command, if the lines
	# have characters, we log them.
	while [[ $curEmpty < $MAXEMPTY ]]; do
		read -t 1 BACK <&5
		if (( ${#BACK} > 0 )); then
			readReply "$BACK"
			curEmpty=0
		else
			curEmpty=$(($curEmpty + 1))
		fi
	done
}

# Set modem into voice mode to listen for digits
listen() {
	log "=== START LISTENING PROCEDURE ==="
	# AT		- Call modem to attention
	# &F0		- Reset modem to defaults
	# +FCLASS=8	- Set the modem into voice mode
	# #CLS=8    /
	#
	# Note: This command may return an error if
	# "AT+FCLASS=?" is called before, as that
	# command can put the modem into voice mode.
	# The error, in that case, does not cause
	# any issues to functions we wish to run.
	if [[ $mType == "#" ]]; then
		wrmodem "AT&F0#CLS=8"
	else
		wrmodem "AT&F0+FCLASS=8"
	fi
	breath

	# Set modem to listen to phone line
	if [[ $mType == "#" ]]; then
		wrmodem "AT#VLS=$vPhone"
	else
		wrmodem "AT+VLS=$vPhone"
	fi
	breath

	# Clear the reply buffer
	emptyBuff

	logSYS "Ready. Listening for Dialing Keys..."
}

# Modem doesn't seem to support a voice mode
# and thus can't read DTMF (Dialing) tones
# so the program now waits for an enter key
# to activate the answer procedure and take
# care of the rest for them
listenEnter() {
	log "=== START LISTENING PROCEDURE ==="

	logNL "$SYS Raedy. Press [Enter] to Answer..."

	# Wait for [Enter]
	read Call </dev/tty

	# Start the Answering Procedure
	answer
}

# Set modem into data mode to answer calls
answer() {
	log "=== START ANSWERING PROCEDURE ==="
	# Hangup the phoneline
	wrmodem "ATH"

	# Critical coming from listening mode we have to give
	# a little time for the modem to hang up.
	sleep 2

	# AT		- Call modem to attention
	# &F0		- Reset modem to defaults
	# &R0		- Tell modem to ignore calls from terminal
	#			( This prevents the modem from halting  )
	#			( an action in order to listen to the   )
	#			( program. This is expecially helpful   )
	#			( to prevent the modem from prematurely )
	#			( ending the answer procedure.          )
	# +FCLASS=0	\_ Set the modem into data mode
	# #CLS=0	/
	if [[ $mType == "#" ]]; then
		wrmodem "AT&F0&R0#CLS=0"
	else
		wrmodem "AT&F0&R0+FCLASS=0"
	fi

	emptyBuff

	# Answer the phoneline
	wrmodem "ATA"
	logSYS "Negotiating Connection"
}

# Start the log and set up the final entry with "trap"
trap 'log "===== LOGGER STOPPED: $BASHPID ====="' EXIT

log       "===== LOGGER STARTED: $BASHPID ====="

# Run the "setup" command.
setup

# Set the program to close streams on exit.
trap 'exec 5<&-' EXIT
trap 'exec 6>&-' EXIT


# Check that the modem has the ability to use voice
# and check for which voice command to use if so.
# Otherwise we alert the user and exit the program.
# This request can be very buggy, and the responses
# can be very inconsistant. So we have to be
# careful how we handle it. That's why the program
# really takes its time getting all the data. Even
# with going slow, there are times where the modem
# doesn't respond in time.
logSYS "Checking for Listening Mode"

# Request the FCLASS abilities of this modem
# Responses list all the different modem
# specifications this modem can preform.
#
# Modes:    Description:
# 1         Data Mode
# 2         Fax
# 8         Voice
#
# Voice allows us to listen for phone key presses.
if [[ $mType == "#" ]]; then
	wrmodem "AT#CLS=?"
else
	wrmodem "AT+FCLASS=?"
fi

# We wait a moment to allow the response to come back
breath

# We then read a series of responses. This command
# generally returns 3-4 lines, but we need a few
# additional lines incase something goes wrong
# or if additional data is in the pipeline.
# So we keep reading until we get MAXEMPTY empty
# returns in a row.
curEmpty=0
while [[ $curEmpty < $MAXEMPTY ]]; do

	# Read from the stream
	read -t 1 BACK <&5

	# If the read has some characters
	# in it, then we log it.
	if (( ${#BACK} > 0 )); then
		filterReply $BACK
		curEmpty=0
	else
		curEmpty=$(($curEmpty + 1))
	fi

	# If the read has information that says
	# this modem has voice mode, then we
	# set the ListenMode to tones.
	if [[ $BACK == *",8"* ]]; then
		logSYS "Listening Mode Available"
		ListenMode=$Tones
	fi
done


# Uncomment the following line to force
# the script to not listen for key tones,
# but wait for "enter" being pressed on
# the keyboard. This can be helpful with
# debugging.
#ListenMode=$Enter


# If this modem supports voice mode, and can
# thus listen to tones, we need to check what
# Voice Mode takes the phone off the hook.
# The issue is there's no standard here for
# the number companies need to use. So
# instead we need to look for the number
# associated with the mode "T".
if [[ $ListenMode == $Tones ]]; then

	logSYS "Setting Modem to Listen"

	# First put the modem into voice mode
	# If we don't do this, the "VLS" command
	# may return "ERROR"
	if [[ $mType == "#" ]]; then
		wrmodem "AT#CLS=8"
	else
		wrmodem "AT+FCLASS=8"
	fi

	# Wait a moment for the modem to respond.
	breath

	# Empties the buffer
	emptyBuff

	logSYS "Checking for 'Line' Mode"

	# Here we request from the modem the
	# different voice modes it can support
	if [[ $mType == "#" ]]; then
		wrmodem "AT#VLS=?"
	else
		wrmodem "AT+VLS=?"
	fi

	# Wait a moment for the modem to respond.
	breath

	# Keep track of the empty responses
	curEmpty=0

	# Some modems have 10+ voice modes they
	# can support. So we keep reading in
	# until we get "maxEmpty" empty returns
	# in a row.
	while [[ $curEmpty < $MAXEMPTY ]]; do
		read -t 1 BACK <&5
		if (( ${#BACK} > 0 )); then
			filterReply $BACK
			curEmpty=0
		else
			curEmpty=$(($curEmpty + 1))
		fi

		# Here we're checking if this line
		# specifies the "T" mode, which is
		# just the modem listening to the
		# phone line. Once that's found
		# we set the "vPhone" variable to it
		if [[ $BACK == *"\"T\""* ]]; then
			vPhone=$(echo $BACK | awk -F "," '{print $1}')
			logSYS "'Line' Mode Found: $vPhone"
		fi

		# After finding the mode we have to
		# continue to read through the loop
		# in order to clear out the stream.
	done
fi

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
	readBuff
	sleep 1
done

# Notes on future improvements:
# The following will fake a dial tone, however there's no known way
# to pump out a dial tone while also listening to the line for
# numbers being dialed. If a solution could be found it would
# be useful for "Quake 3 Arena". Alternatively one might want to
# look into playing an audio file of a dial tone rather than
# using this command to generate it.
#
# First two parameters set the frequency.
# Third parameter is time in (miliseconds/10) from [0 - 255]
#	wrmodem "AT+VTS=[440,350,255]"
