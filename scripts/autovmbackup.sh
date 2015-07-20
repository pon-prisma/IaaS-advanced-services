#!/bin/bash

PATH=/usr/sbin:/usr/bin:/sbin:/bin

# OpenStack Credential
export OS_TENANT_NAME=
export OS_USERNAME=
export OS_PASSWORD=
export OS_AUTH_URL=

#=======================================================================#
# VM and volume backup.                                                  #
#=======================================================================#
#                                                                       # 
# Daily Backups are rotated weekly.                                     #
#                                                                       #
# Weekly Backups are run by default on Monday Morning when              #
# cron.daily scripts are run. This can be changed with DOWEEKLY setting.#
#                                                                       #
# Weekly Backups are rotated on a 5 week cycle.                         #
#                                                                       #
#=======================================================================#

# Which day do you want weekly backups? (1 to 7 where 1 is Monday)
DOWEEKLY=1

image_create () {
        nova --insecure image-create $1 $2
        if wait_backup $VMBACKUPNAME
                then
                        echo "Backup of $VMNAME completed successfully"
                        echo "Image name: $VMBACKUPNAME"
                else
                        echo "Backup of $VMNAME failed"
        fi
        return 0
}

image_delete () {
        VMID=$(nova --insecure show $1 | awk '/\yid\y/{print $4}' | grep -v id)
        BACKUPLIST=($(nova --insecure image-list | grep $VMID | awk '{print $4}'))
        for IMAGENAME in ${BACKUPLIST[@]}
                do
                        if [[ "$IMAGENAME" == "$2"* ]]; then
                                echo "The image $IMAGENAME will be deleted due to rotation"
                                nova --insecure image-delete $IMAGENAME
                        fi
                done
        return 0
}

wait_vm_started () {
    # wait 5 minutes (30 times 10 seconds)
        VMID=$1
        let i=0
        STATUS=" "
        while [ $i -lt 30 -a "$STATUS" != "active" ]
        do
                let i++
                STATUS=$(nova --insecure show $VMID | awk '/OS-EXT-STS:vm_state/{print $4}')
                echo "VM status is <$STATUS>"
                [ "$STATIS" = "active" ] && continue
                sleep 10
        done
        return 0
}

wait_vm_stopped () {
    # wait 5 minutes (30 times 10 seconds)
    [ "$status" = stopped ]

        VMID=$1
        let i=0
        STATUS=" "
        while [ $i -lt 30 -a "$STATUS" != "stopped" ]
        do
                let i++
                STATUS=$(nova --insecure show $VMID | awk '/OS-EXT-STS:vm_state/{print $4}')
                echo "VM status is <$STATUS>"
                [ "$STATUS" = "stopped" ] && continue
                sleep 10
        done
        return 0
}

wait_backup () {
        # wait 1h (12 times 5 minutes)
        BACKUP_NAME=$1
        let i=0
        STATUS=" "
        while [ $i -lt 12 -a "$STATUS" != "ACTIVE" ]
                do
                        let i++
                        STATUS="$(nova --insecure image-show $BACKUP_NAME | awk '/status/{print $4}')"
                        echo "BACKUP status is <$STATUS>"
                        [ "$STATUS" = "ACTIVE" ] && continue
                        sleep 5m
                done
        return 0
}

volume_snapshot_create () {
        echo "Starting backup for volume $2"
        cinder --insecure snapshot-create --force True --display-name $1 $2
        ### Controllo sull'esecuzione del backup
        echo "Backup for volume $2 completed. Backup name: $1"
        return 0
}

volume_snapshot_delete () {
        VOLUMEID=$(cinder --insecure show $VOLUMENAME | awk '/\yid\y/{print $4}' | grep -v device)
        VOLUMESNAPSHOTLIST=($(cinder --insecure snapshot-list  | grep $VOLUMEID | awk '{print $8}'))
        for SNAPSHOT in ${VOLUMESNAPSHOTLIST[@]}
        do
                if [[ "$SNAPSHOT" == "$1"* ]]; then
                        echo "Deleting volume backup $SNAPSHOT due to rotation"
                        cinder --insecure snapshot-delete $SNAPSHOT
                        ### Controllo
                        echo "Backup volume $SNAPSHOT deleted."
                fi
        done
        return 0
}

backup_rotation () {
# Weekly Backup
if [ $DNOW = $DOWEEKLY ]; then
        echo Weekly Backup
        echo
        echo Rotating 2 weeks Backups...
        if [ "$W" -le 02 ]; then
                REMW=`expr 51 + $W`
        elif [ "$W" -lt 12 ]; then
                REMW=0`expr $W - 2`
        else
                REMW=`expr $W - 2`
        fi

        if [ ! -z $VMNAME ]; then
                VMBACKUPDELETE=$VMNAME.$REMW.
                #image_delete $VMNAME $VMNAME.$REMW.
                VMBACKUPNAME=$VMNAME.$W.$DATE
        fi
	
	if [ ${#VOLUMENAMES[@]} -gt 0 ]; then
                VOLUMEBACKUPDELETES=()
                VOLUMEBACKUPNAMES=()
                for VOLUMENAME in ${VOLUMENAMES[@]}
                        do
                                VOLUMEBACKUPDELETES+=($VOLUMENAME.$REMW.)
                                VOLUMEBACKUPNAMES+=($VOLUMENAME.$W.$DATE)
                        done

        fi
# Daily Backup
else
        echo Daily Backup
        echo
        echo Rotating last week Backups...
        echo

        if [ ! -z $VMNAME ]; then
                VMBACKUPDELETE=$VMNAME.$DOW.
                #image_delete $VMNAME $VMNAME.$DOW.
                VMBACKUPNAME=$VMNAME.$DOW.$DATE
        fi

#       if [ ! -z $VOLUMENAME ]; then
#               VOLUMEBACKUPDELETE=$VOLUMENAME.$DOW.
#               #volume_snapshot_delete $VOLUMENAME.$DOW.
#               VOLUMEBACKUPNAME=$VOLUMENAME.$DOW.$DATE
#       fi


        if [ ${#VOLUMENAMES[@]} -gt 0 ]; then
                VOLUMEBACKUPDELETES=()
                VOLUMEBACKUPNAMES=()
                for VOLUMENAME in ${VOLUMENAMES[@]}
                        do
                                VOLUMEBACKUPDELETES+=($VOLUMENAME.$DOW.)
                                VOLUMEBACKUPNAMES+=($VOLUMENAME.$DOW.$DATE)
                        done

        fi
fi
return 0
}

# Start script

BACKUPDIR=/root/vmbackup

# Script arguments
while [[ $# > 0 ]]
do
arg="$1"

case $arg in
        --vmname)
        VMNAME="$2"
        shift
        ;;
        --type)
        BACKUPTYPE="$2"
        shift
        ;;
        --volume)
        VOLUMENAME=$2 && shift
        VOLUMENAMES=($@)
        shift
        ;;
        *)
        echo "I don't understand what you want to do"
        echo "Usage:"
	echo "./backup-script.sh [--vmname <virtual machine name>]"
	echo "                   [--type <live|cold>]"
	echo "                   [--volume <volume name> <volume name> ...]"
esac
shift
done

DATE=`date +%Y-%m-%d_%Hh%Mm`                        		# Datestamp e.g 2002-09-21
DOW=`date +%A`                                      		# Day of the week e.g. Monday
DNOW=`date +%u`                                     		# Day number of the week 1 to 7 where 1 represents Monday
DOM=`date +%d`                                      		# Date of the Month e.g. 27
M=`date +%B`                                        		# Month e.g January
W=`date +%V`                                        		# Week Number e.g 37
#LOGFILE=$BACKUPDIR/$0-`date +%H%M`.log       			# Logfile Name
#LOGERR=$BACKUPDIR/$0-ERRORS-`date +%H%M`.log 			# Logfile Name
LOGFILE=$BACKUPDIR/$0-$DATE.log       			        # Logfile Name
LOGERR=$BACKUPDIR/$0-ERRORS-$DATE.log 			        # Logfile Name

# IO redirection for logging.
touch $LOGFILE
exec 6>&1           # Link file descriptor #6 with stdout.
                    # Saves stdout.
exec > $LOGFILE     # stdout replaced with file $LOGFILE.

touch $LOGERR
exec 7>&2           # Link file descriptor #7 with stderr.
                    # Saves stderr.
exec 2> $LOGERR     # stderr replaced with file $LOGERR.

echo ======================================================================
echo Starting Backup Script

echo Backup Start `date`
echo ======================================================================

# Set variables for the backup rotation
backup_rotation

# Virtual Machine backup
if [ ! -z "$VMNAME" ]; then
	echo "Starting virtual machine $VMNAME backup"
        # Check virtual machine task state
        VM_TASK_STATE=`nova --insecure show $VMNAME | awk '/task_state/{print $4}'`
        if [ "$VM_TASK_STATE" != "-" ]; then
                echo "Couldn't perform the snapshot because VM is in $VM_TASK_STATE task state"
        else
                if [ "$BACKUPTYPE" == "live" ]; then
                        echo "Live snapshot started for VM $VMNAME: $VMBACKUPNAME"
                        image_delete $VMNAME $VMBACKUPDELETE
                        image_create $VMNAME $VMBACKUPNAME
                elif [ "$BACKUPTYPE" == "cold" ]; then
                        echo "Cold snapshot started for VM $VMNAME: $VMBACKUPNAME"
                        echo "Shutting down VM $VMNAME"
                        nova --insecure stop $VMNAME
                        if wait_vm_stopped $VMNAME
                        then
                                echo "VM $VMNAME stopped!"
                        else
                                echo "ERROR: can't stop the VM $VMNAME. Can't do the cold backup."
                        fi
                        image_delete $VMNAME $VMBACKUPDELETE
                        image_create $VMNAME $VMBACKUPNAME
                        echo "Starting up VM $VMNAME"
                        nova --insecure start $VMNAME
                        if wait_vm_started $VMNAME; then
                                echo "VM $1 started!"
                        else
                                echo "ERROR: can't start the VM $VMNAME"
                        fi
                else
                        echo "$BACKUPTYPE unknown backup type, please set live or cold" 
                fi
        fi
fi

# Volume(s) backup
if [ ${#VOLUMENAMES[@]} -gt 0 ]; then
        echo "Starting volume(s) backup"

        for VOLUMENAME in ${VOLUMENAMES[@]}
                do
                        for VOLUMEBACKUPDELETE in ${VOLUMEBACKUPDELETES[@]}
                                do
                                        if [[ "$VOLUMEBACKUPDELETE" == "$VOLUMENAME".* ]]; then
                                                volume_snapshot_delete $VOLUMEBACKUPDELETE
                                        fi
                                done
                        for VOLUMEBACKUPNAME in ${VOLUMEBACKUPNAMES[@]}
                                do
                                        if [[ "$VOLUMEBACKUPNAME" == "$VOLUMENAME".* ]]; then
                                                volume_snapshot_create $VOLUMEBACKUPNAME $VOLUMENAME
                                        fi
                                done
                done
fi

echo ----------------------------------------------------------------------
echo Backup End Time `date`
echo ======================================================================
exit 0

