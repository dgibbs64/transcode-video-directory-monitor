#!/bin/bash
# transcode-video directory monitor
# Description: Monitors a directory for video files to transcode using transcode-video script
# Author: Daniel Gibbs
# E-Mail: me@danielgibbs.co.uk
# Version: 221115

if [ -f ".dev-debug" ]; then
	exec 5>dev-debug.log
	BASH_XTRACEFD="5"
	set -x
fi

# Script name
scriptname=$(basename $(readlink -f "${BASH_SOURCE[0]}"))
# Current dir
rootdir="$(dirname $(readlink -f "${BASH_SOURCE[0]}"))"


# Messages

# [ FAIL ]
fn_printfailnl(){
		echo -e "\r\033[K[\e[0;31m FAIL \e[0m] $@"
}

# [  OK  ]
fn_printoknl(){
		echo -e "\r\033[K[\e[0;32m  OK  \e[0m] $@"
}

# [ INFO ]
fn_printinfonl(){
		echo -e "\r\033[K[\e[0;36m INFO \e[0m] $@"
}

# [ .... ]
fn_printdots(){
		echo -en "\r\033[K[ .... ] $@"
}


# Checks for lock file
lockfile="${scriptname}.lock"
if [ -f "${lockfile}" ]; then
	fn_printinfonl "Lock file found: ${scriptname} already running!"
	exit
fi

date +%s > "${lockfile}"

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
        echo "Removed ${lockfile}"
        rm -f "${rootdir}/${lockfile}"
}

# Main Script

inputdir="/home/user/input"
outputdir="/home/user/output"

cd "${inputdir}"

#find "${inputdir}" -type d -depth -empty -delete

find . -type f | while read video; do
	
	fn_printinfonl "Found ${video} in ${inputdir}"
	sleep 1
	last="0"
	current=$(find "${video}" -exec stat -c "%Y" \{\} \; \
			| sort -n | tail -1)
	fn_printdots "Checking file size changes: ${current}"
	while [ "${last}" != "${current}" ]; do
		sleep 5
		last=$current
		current=$(find "${video}" -exec stat -c "%Y" \{\} \; \
			| sort -n | tail -1)
		fn_printdots "Checking file size changes: ${current}"
	done
	sleep 1
	fn_printoknl "Checking file size changes: Complete!"
	sleep 1
	videomime=$(file -b --mime-type "${video}")
	videosize=$(du -h "${video}" | awk '{print $1}')
	echo "================================="
	echo "File name: ${video}"
	echo "File mime type: ${videomime}"
	echo "File size: ${videosize}"
	echo "================================="
	sleep 1
	if [ "${videomime}" == "video/x-matroska" ]; then
		mkdir -p "${outputdir}/output" > /dev/null 2>&1
		cd "${outputdir}/output"
		fn_printoknl "Starting Conversion"
		sleep 1
		/usr/local/bin/transcode-video --mp4 --add-audio language=eng "${inputdir}/${video}"
		if [ "${?}" != "0" ]; then
			fn_printfailnl "Unable to transcode: transcode-video.sh failed to transcode video"
			mkdir -p "${outputdir}/fail" > /dev/null 2>&1
			cd "${inputdir}"
			rsync -avz --progress --stats "${video}" "${outputdir}/fail"
			if [ "${?}" == "0" ]; then
				rm -f "${video}"
				rm -f "${rootdir}/${lockfile}"
				exit
			else
				fn_printfailnl "Copying failed!"
				rm -f "${rootdir}/${lockfile}"
				exit 1
			fi	
		else
			fn_printoknl "Conversion complete."
			sleep 1
			fn_printdots "Conversion complete: moving original."
			mkdir -p "${outputdir}/original" > /dev/null 2>&1
			cd "${inputdir}"
			rsync -avz --progress --stats "${video}" "${outputdir}/original/"
			if [ "${?}" == "0" ]; then
				fn_printoknl "Conversion complete: moving original."
				rm -f "${video}"
				rm -f "${rootdir}/${lockfile}"
				exit
			else
				fn_printfailnl "Conversion complete: moving original."
				rm -f "${rootdir}/${lockfile}"
				exit 1
			fi				
		fi
	else
		fn_printfailnl "Conversion failed: not an valid video file"
		sleep 1
		fn_printdots "Conversion failed: moving original."
		mkdir -p "${outputdir}/fail" > /dev/null 2>&1
		cd "${inputdir}"
		rsync -avz --progress --stats "${video}" "${outputdir}/fail"
		if [ "${?}" == "0" ]; then
			fn_printoknl "Conversion failed: moving original."
			rm -f "${video}"
			rm -f "${rootdir}/${lockfile}"
			exit
		else
			fn_printfailnl "Conversion failed: moving original."
			rm -f "${rootdir}/${lockfile}"
			exit 1
		fi	

	fi	
done

if [ -f "${rootdir}/${lockfile}" ]; then
	rm -f "${rootdir}/${lockfile}"
fi
