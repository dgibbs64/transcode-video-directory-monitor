#!/bin/bash
# convert-video monitor
# Description: Monitors a directory for video files to convert using convert-video script
# Author: Daniel Gibbs
# E-Mail: me@danielgibbs.co.uk
# Version: 250116

if [ -f ".dev-debug" ]; then
	exec 5>dev-debug.log
	BASH_XTRACEFD="5"
	set -x
fi

# Script name
scriptname=$(basename $(readlink -f "${BASH_SOURCE[0]}"))
# Current dir
rootdir="$(dirname $(readlink -f "${BASH_SOURCE[0]}"))"

inputdir="/SOME/DIR"
outputdir="/SOME/DIR"

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


fn_fail_transfer(){
	mkdir -p "${outputdir}/fail" > /dev/null 2>&1
	cd "${inputdir}" || exit
	rsync -avz --progress --stats "${video}" "${outputdir}/fail"
	if [ "${?}" == "0" ]; then
		rm -f "${video}"
		rm -f "${rootdir}/${lockfile}"
		fn_printoknl "Conversion failed: $(date '+%b %d %H:%M:%S') moving original."
		exit
	else
		rm -f "${rootdir}/${lockfile}"
		fn_printfailnl "Conversion failed: $(date '+%b %d %H:%M:%S') moving original."
		exit 1
	fi	
}

fn_original_transfer(){
	cd "${inputdir}" || exit
	rsync -avz --progress --stats "${video}" "${outputdir}/original/"
	if [ "${?}" == "0" ]; then
		rm -f "${video}"
		rm -f "${rootdir}/${lockfile}"
		fn_printoknl "Conversion complete: $(date '+%b %d %H:%M:%S') moving original to original dir."
		exit
	else
		rm -f "${rootdir}/${lockfile}"
		fn_printfailnl "Conversion complete: $(date '+%b %d %H:%M:%S') moving original to original dir."
		exit 1
	fi		
}

fn_display_info(){
	# display info
	videomime=$(file -b --mime-type "${video}")
	videosize=$(du -h "${video}" | awk '{print $1}')
	echo "================================="
	echo "File name: ${video}"
	echo "File mime type: ${videomime}"
	echo "File size: ${videosize}"
	echo "================================="
	sleep 1		
}

fn_check_filesize(){
	# file changes check
	last="0"
	current=$(find "${video}" -exec stat -c "%Y" \{\} \; \
			| sort -n | tail -1)
	fn_printdots "Checking file size changes: ${current}"
	while [ "${last}" != "${current}" ]; do
		last=$current
		current=$(find "${video}" -exec stat -c "%Y" \{\} \; \
			| sort -n | tail -1)
		fn_printdots "Checking file size changes: ${current}"
		sleep 5
	done
	fn_printoknl "Checking file size changes: Complete!"
	sleep 1
}

# Checks for lock file
lockfile="${scriptname}.lock"
if [ -f "${rootdir}/${lockfile}" ]; then
	exit
fi

date +%s > "${rootdir}/${lockfile}"

# trap ctrl-c and call ctrl_c()
trap finish EXIT

function finish {
	echo "Removed ${lockfile}"
	rm -f "${rootdir}/${lockfile}"
}

cd "${inputdir}" || exit

# Look in input for files
find "${inputdir}" -type f | while read -r video; do
	# remove dir's from full path leaving just the nane 
	find "${video}" -type f -printf '%f\n'
	fn_printinfonl "Found $(basename "${video}") in ${inputdir}"
	sleep 1

	fn_check_filesize
	fn_display_info


	if [ "${videomime}" == "video/x-matroska" ]; then
		mkdir -p "${outputdir}/output" > /dev/null 2>&1
		cd "${outputdir}/output" || exit
		if [ -f "$(basename "${video%.*}").mp4" ]; then
			fn_printinfonl "$(basename "${video%.*}").mp4 already exists. Removing file to start again."
			rm -f "$(basename "${video%.*}").mp4"
		fi	
		echo "$(basename "${video%.*}").mp4"
		fn_printoknl "Starting Conversion"
		sleep 1
		#/usr/local/bin/convert-video "${video}"
		/home/user/convert-video.sh "${video}" >> /home/user/nas-Downloads/convert-video/video-convert-monitor.log
		exitcode=${?}
		if [ "${exitcode}" != "0" ]; then
			fn_printfailnl "Unable to convert: convert-video.sh failed to convert video"
			fn_fail_transfer
		else
			fn_printoknl "Conversion complete."
			fn_original_transfer
		fi	
	else
		fn_printfailnl "Conversion failed: not an mkv file"
		fn_fail_transfer
	fi
done