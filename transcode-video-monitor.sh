#!/bin/bash
# transcode-video directory monitor
# Description: Monitors a directory for video files to transcode using transcode-video script
# Author: Daniel Gibbs
# E-Mail: me@danielgibbs.co.uk
# Version: 221115

# Lockfile
scriptname=$(basename $(readlink -f "${BASH_SOURCE[0]}"))
pidfile="${scriptname}.lock"
# lock it
exec 200 > ${pidfile}
flock -n 200 || exit 1
pid=$$
echo ${pid} 1>&200


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


# Main Script

inputdir="/home/user/nas-Downloads/transcode-video/input"
outputdir="/home/user/nas-Downloads/transcode-video/output"

cd "${inputdir}"
find * -type f -print -name "*.mkv"  -o -name "*.avi" -o -name "*.mp4" -o -name "*.mov" -o -name "*.wmv" | while read video; do 
	fn_printinfonl "Found ${video} in ${inputdir}"
	sleep 1
	fn_printdots "Checking if file is still being copied to ${inputdir}"
	last="0"
	current=$(find "${video}" -exec stat -c "%Y" \{\} \; \
		| sort -n | tail -1)
	while [ "${last}" != "${current}" ]; do
		sleep 15 
		last=$current
		current=$(find "${video}" -exec stat -c "%Y" \{\} \; \
			| sort -n | tail -1)
		fn_printdots "Checking file size changes: ${current}"
	done
	sleep 1
	fn_printoknl "Checking file size changes: Complete!"
	cd "${outputdir}"
	fn_printoknl "Starting Transcode"
	sleep 1
	/usr/local/bin/transcode-video --mp4 --add-audio language=eng "${inputdir}/${video}"
	if [ "${?}" != "0" ]; then
		fn_printfailnl "Unable to transcode: moving to fail dir"
		mkdir -p "${outputdir}/fail" > /dev/null 2>&1
		cd "${inputdir}"
		rsync -avz --progress --stats "${video}" "${outputdir}/fail"
		rm -f "${video}"
		rm -f "${outputdir}/${video}"
	else
		fn_printoknl "Transcode complete!"
		mkdir -p "${outputdir}/original" > /dev/null 2>&1
		cd "${inputdir}"
		rsync -avz --progress --stats "${video}" "${outputdir}/original/"
		rm -f "${video}"
	fi
done
