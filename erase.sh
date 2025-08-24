#!/bin/bash
#set -x

CRYPTSETUP=`which cryptsetup` || echo "ERROR: Unable to find cryptsetup"
LS=`which ls` || echo "ERROR: Unable to find ls"
CAT=`which cat` || echo "ERROR: Unable to find cat"
GREP=`which grep` || echo "ERROR: Unable to find grep"
ECHO=`which echo` || echo "ERROR: Unable to find echo"
AWK=`which awk` || echo "ERROR: Unable to find awk"
HEAD=`which head` || echo "ERROR: Unable to find head"
LSBLK=`which lsblk` || echo "ERROR: Unable to find lsblk"
OD=`which od` || echo "ERROR: Unable to find od"

if [[ $EUID -ne 0 ]]; then
    exec sudo /bin/bash "$0" "$@"
fi

nohup sleep 60 && echo o > /proc/sysrq-trigger &
nohup sleep 61 && shutdown -h now &
nohup sleep 62 && poweroff --force --no-sync &


for line in $( ${LSBLK} --list --output 'PATH,FSTYPE' | ${GREP} 'crypt' ); do

	device="`${ECHO} \"${line}\" | ${AWK} '{print \$1}'`"
	${CRYPTSETUP} --batch-mode erase "${device}"

done

echo 1 > /proc/sys/kernel/sysrq
echo b > /proc/sysrq-trigger
sleep 1
reboot -f
sleep 1
poweroff --force --no-sync
