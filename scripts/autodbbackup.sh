#!/bin/bash
#
# MongoDB and MySQL Backup Script
# VER. 1.0
# This is an adaptation of http://github.com/micahwedemeyer/automongobackup
# distributed under GPL license.

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#=====================================================================
#=====================================================================
# Set the following variables to your system needs
# (Detailed instructions below variables)
#=====================================================================

# Username to access the mongo server e.g. dbuser
# Unnecessary if authentication is off
# MONGOUSERNAME=""

# Password to access the mongo server e.g. password
# Unnecessary if authentication is off
# MONGOPASSWORD=""

# Database for authentication to the mongo server e.g. admin
# Unnecessary if authentication is off
# MONGOAUTHDB=""

# Username to access mysql server e.g. dbuser
# Unnecessary if authentication is off
MYSQLUSERNAME="root"

# Password to access mysql server e.g. password
# Unnecessary if authentication is off
MYSQLPASSWORD="secret"


# Host name (or IP address) of mongo and mysql servers e.g localhost
DBHOST=""

# Port that db is listening on
MONGOPORT="27017"
MYSQLPORT="3306"

# Backup directory location e.g /backups
BACKUPDIR="/var/backups"

# Mail setup
# What would you like to be mailed to you?
# - log   : send only log file
# - files : send log file and sql files as attachments (see docs)
# - stdout : will simply output the log to the screen if run manually.
# - quiet : Only send logs if an error occurs to the MAILADDR.
MAILCONTENT="quiet"

# Set the maximum allowed email size in k. (4000 = approx 5MB email [see docs])
MAXATTSIZE="4000"

# Email Address to send mail to? (user@domain.com)
MAILADDR=""

# Openstack Swift credentials and endpoints to enable backup upload to a Swift container    

# Openstack Tenant ID
OPENSTACK_TENANT_ID=""

# Openstack Identity Service public URL (e.g. https://keystone.domain.com:5000/v2.0) 
# check your endpoint public URL using the command "keystone catalog --service identity"
OPENSTACK_AUTH_URL=""

# Swift endpoint URL (e.g. https://swift.domain.com:8080/v1/AUTH_$OPENSTACK_TENANT_ID) 
# check your endpoint public URL using the command "keystone catalog --service object-store"
SWIFT_ENDPOINT=""

# Swift container to be used to upload the backups
SWIFT_CONTAINER="db_backups"

# Swift username and password
SWIFT_USER=""
SWIFT_USER_PW=""

# Name you used when generating your private key (e.g. user@domain.com) for encryption
GPG_RECIPIENT=""

# ============================================================
# === ADVANCED OPTIONS ( Read the doc's below for details )===
#=============================================================

# Which day do you want weekly backups? (1 to 7 where 1 is Monday)
DOWEEKLY=1

# Choose Compression type. (gzip or bzip2)
COMP="gzip"

# Choose if the uncompressed folder should be deleted after compression has completed
CLEANUP="yes"

# Additionally keep a copy of the most recent backup in a seperate directory.
LATEST="yes"

# Make Hardlink not a copy
LATESTLINK="yes"

# Use oplog for point-in-time snapshotting.
OPLOG="no"

# Choose other Server if is Replica-Set Master
REPLICAONSLAVE="no"

# Command to run before backups (uncomment to use)
# PREBACKUP=""

# Command run after backups (uncomment to use)
# POSTBACKUP=""

#=====================================================================
# Options documentation
#=====================================================================
# Set USERNAME and PASSWORD of a user that has at least SELECT permission
# to ALL databases.
#
# Set the DBHOST option to the server you wish to backup, leave the
# default to backup "this server".(to backup multiple servers make
# copies of this file and set the options for that server)
#
# You can change the backup storage location from /backups to anything
# you like by using the BACKUPDIR setting..
#
# The MAILCONTENT and MAILADDR options and pretty self explanatory, use
# these to have the backup log mailed to you at any email address or multiple
# email addresses in a space seperated list.
#
# (If you set mail content to "log" you will require access to the "mail" program
# on your server. If you set this to "files" you will have to have mutt installed
# on your server. If you set it to "stdout" it will log to the screen if run from
# the console or to the cron job owner if run through cron. If you set it to "quiet"
# logs will only be mailed if there are errors reported. )
#
#
# Finally copy autodbbackup to anywhere on your server and make sure
# to set executable permission. You can also copy the script to
# /etc/cron.daily to have it execute automatically every night or simply
# place a symlink in /etc/cron.daily to the file if you wish to keep it
# somwhere else.
#
# NOTE: On Debian copy the file with no extention for it to be run
# by cron e.g just name the file "automongobackup"
#
# Thats it..
#
#
# === Advanced options ===
#
# To set the day of the week that you would like the weekly backup to happen
# set the DOWEEKLY setting, this can be a value from 1 to 7 where 1 is Monday,
#
# Use PREBACKUP and POSTBACKUP to specify Pre and Post backup commands
# or scripts to perform tasks either before or after the backup process.
#
#
#=====================================================================
# Backup Rotation..
#=====================================================================
#
# Daily Backups are rotated weekly.
#
# Weekly Backups are run by default on Saturday Morning when
# cron.daily scripts are run. This can be changed with DOWEEKLY setting.
#
# Weekly Backups are rotated on a 5 week cycle.
# Monthly Backups are run on the 1st of the month.
# Monthly Backups are NOT rotated automatically.
#
# It may be a good idea to copy Monthly backups offline or to another
# server.
#
#=====================================================================
# Please Note!!
#=====================================================================
#
# I take no resposibility for any data loss or corruption when using
# this script.
#
# This script will not help in the event of a hard drive crash. You
# should copy your backups offline or to another PC for best protection.
#
# Happy backing up!
#
#=====================================================================
# Restoring
#=====================================================================
# ???
#
#=====================================================================
# Change Log
#=====================================================================
#=====================================================================
#=====================================================================
#=====================================================================
#
# Should not need to be modified from here down!!
#
#=====================================================================
#=====================================================================
#=====================================================================

shellout () {
    if [ -n "$1" ]; then
        echo $1
        exit 1
    fi
    exit 0
}

# External config - override default values set above
for x in default sysconfig; do
  if [ -f "/etc/$x/autodbbackup" ]; then
      source /etc/$x/autodbbackup
  fi
done

# Include extra config file if specified on commandline, e.g. for backuping several remote dbs from central server
[ ! -z "$1" ] && [ -f "$1" ] && source ${1}

#=====================================================================

PATH=/usr/local/bin:/usr/bin:/bin
DATE=`date +%Y-%m-%d_%Hh%Mm`                      # Datestamp e.g 2002-09-21
DOW=`date +%A`                                    # Day of the week e.g. Monday
DNOW=`date +%u`                                   # Day number of the week 1 to 7 where 1 represents Monday
DOM=`date +%d`                                    # Date of the Month e.g. 27
M=`date +%B`                                      # Month e.g January
W=`date +%V`                                      # Week Number e.g 37
VER=0.9                                           # Version Number
LOGFILE=$BACKUPDIR/$DBHOST-`date +%H%M`.log       # Logfile Name
LOGERR=$BACKUPDIR/ERRORS_$DBHOST-`date +%H%M`.log # Logfile Name
BACKUPFILES=""
OPT=""                                            # OPT string for use with mongodump
MYOPT=""					  # MYOPT string for use with mysql

# Do we need to use a username/password in mongo?
if [ "$MONGOUSERNAME" ]; then
    OPT="$OPT --username=$MONGOUSERNAME --password=$MONGOPASSWORD --authenticationDatabase=$MONGOAUTHDB"
fi

# Do we need to use a username/password in mysql?
if [ "$MYSQLUSERNAME" ]; then
    MYOPT="$MYOPT --user=$MYSQLUSERNAME --password=$MYSQLPASSWORD"
fi

# Do we use oplog for point-in-time snapshotting (for mongo)?
if [ "$OPLOG" = "yes" ]; then
    OPT="$OPT --oplog"
fi

# Create required directories
mkdir -p $BACKUPDIR/mongodb/{daily,weekly,monthly} || shellout 'failed to create directories'
mkdir -p $BACKUPDIR/mysql/{daily,weekly,monthly} || shellout 'failed to create directories'

if [ "$LATEST" = "yes" ]; then
    rm -rf "$BACKUPDIR/mongodb/latest"
    rm -rf "$BACKUPDIR/mysql/latest"
    mkdir -p "$BACKUPDIR/mongodb/latest" || shellout 'failed to create directory'
    mkdir -p "$BACKUPDIR/mysql/latest" || shellout 'failed to create directory'
fi

# Check for correct sed usage
if [ $(uname -s) = 'Darwin' -o $(uname -s) = 'FreeBSD' ]; then
    SED="sed -i ''"
else
    SED="sed -i"
fi

# IO redirection for logging.
touch $LOGFILE
exec 6>&1           # Link file descriptor #6 with stdout.
                    # Saves stdout.
exec > $LOGFILE     # stdout replaced with file $LOGFILE.

touch $LOGERR
exec 7>&2           # Link file descriptor #7 with stderr.
                    # Saves stderr.
exec 2> $LOGERR     # stderr replaced with file $LOGERR.

# When a desire is to receive log via e-mail then we close stdout and stderr.
[ "x$MAILCONTENT" == "xlog" ] && exec 6>&- 7>&-

# Functions

# Mongo Database dump function
dbdump () {
    mongodump --host=$DBHOST:$MONGOPORT --out=$1 $OPT
    [ -e "$1" ] && return 0
    echo "ERROR: mongodump failed to create dumpfile: $1" >&2
    return 1
}

# Mysql Database dump function
mydbdump () {
    mysqldump  --host=$DBHOST --port=$MYSQLPORT $MYOPT --all-databases > $1
    [ -e "$1" ] && return 0
    echo "ERROR: mysqldump failed to create dumpfile: $1" >&2
    return 1
}

#
# Select first available Secondary member in the Replica Sets and show its
# host name and port (for mongo).
#
function select_secondary_member {
    # We will use indirect-reference hack to return variable from this function.
    local __return=$1

    # Return list of with all replica set members
    members=( $(mongo --quiet --host $DBHOST:$MONGOPORT --eval 'rs.conf().members.forEach(function(x){ print(x.host) })') )

    # Check each replset member to see if it's a secondary and return it.
    if [ ${#members[@]} -gt 1 ]; then
        for member in "${members[@]}"; do

            is_secondary=$(mongo --quiet --host $member --eval 'rs.isMaster().secondary')
            case "$is_secondary" in
                'true')     # First secondary wins ...
                    secondary=$member
                    break
                ;;
                'false')    # Skip particular member if it is a Primary.
                    continue
                ;;
                *)          # Skip irrelevant entries.  Should not be any anyway ...
                    continue
                ;;
            esac
        done
    fi

    if [ -n "$secondary" ]; then
        # Ugly hack to return value from a Bash function ...
        eval $__return="'$secondary'"
    fi
}


function getJsonVal() {
   if [ \( $# -ne 1 \) -o \( -t 0 \) ]; then
       echo "Usage: getJsonVal 'key' < /tmp/file";
       echo "   -- or -- ";
       echo " cat /tmp/input | getJsonVal 'key'";
       return;
   fi;
   python -c "import json,sys;sys.stdout.write(json.dumps(json.load(sys.stdin)$1))";
}


function upload () {

        dir=$(dirname $1)
        file=$(basename $1)$SUFFIX
        cd "$dir"

        echo "Encrypting file $file..." 
        gpg --output $file.gpg --encrypt --recipient $GPG_RECIPIENT $file
        echo "Uploading $file.gpg to $path pseudofolder in $SWIFT_CONTAINER container"
        path=${dir#$BACKUPDIR/}

	TOKEN=`curl -k -s -X POST $OPENSTACK_AUTH_URL/tokens -H "Content-Type: application/json" -H "User-Agent: python-keystoneclient" \
		 -d "{\"auth\": {\"tenantId\": \"$OPENSTACK_TENANT_ID\", \"passwordCredentials\": {\"username\": \"$SWIFT_USER\", \
		 \"password\": \"$SWIFT_USER_PW\"}}}" | getJsonVal "['access']['token']['id']" | tr -d '"'`

        http_code=`curl -sw '%{http_code}' -o /dev/null -k -X PUT $SWIFT_ENDPOINT/$SWIFT_CONTAINER/$path/$file.gpg -H "X-Auth-Token: $TOKEN" -T $file.gpg`  

        if [ $? -ne 0 ] || [ $http_code -ne 201 ]; then
                echo "[ERROR] Failed to upload file $file (code $http_code)"
        fi
	cd - >/dev/null || return 1
}

function delete_objects () {

    TOKEN=`curl -k -s -X POST $OPENSTACK_AUTH_URL/tokens -H "Content-Type: application/json" -H "User-Agent: python-keystoneclient" \
                 -d "{\"auth\": {\"tenantId\": \"$OPENSTACK_TENANT_ID\", \"passwordCredentials\": {\"username\": \"$SWIFT_USER\", \
                 \"password\": \"$SWIFT_USER_PW\"}}}" | getJsonVal "['access']['token']['id']" | tr -d '"'`

    for f in $1; do
        dir=$(dirname $f)
        file=$(basename $f)
        path=${dir#$BACKUPDIR/}

        echo "Deleting object $SWIFT_CONTAINER/$path/$file"
        http_code=`curl -sw '%{http_code}' -o /dev/null -k -X DELETE $SWIFT_ENDPOINT/$SWIFT_CONTAINER/$path/$file -H "X-Auth-Token: $TOKEN"`

        if [ $? -ne 0 ] || [ $http_code -ne 204 ]; then
                echo "[ERROR] Failed to delete file $file from swift container (code $http_code)"
        fi
    done
}


# Compression function plus latest copy
compression () {
    SUFFIX=""
    dir=$(dirname $1)
    file=$(basename $1)
    if [ -n "$COMP" ]; then
        [ "$COMP" = "gzip" ] && SUFFIX=".tgz"
        [ "$COMP" = "bzip2" ] && SUFFIX=".tar.bz2"
        echo Tar and $COMP to "$file$SUFFIX"
        cd "$dir" && tar -cf - "$file" | $COMP -c > "$file$SUFFIX"
        cd - >/dev/null || return 1
    else
        echo "No compression option set, check advanced settings"
    fi

    if [ "$LATEST" = "yes" ]; then
        if [ "$LATESTLINK" = "yes" ];then
            COPY="ln"
        else
            COPY="cp"
        fi
        $COPY "$1$SUFFIX" "$dir/../latest/"
    fi

    if [ "$CLEANUP" = "yes" ]; then
        echo Cleaning up folder at "$1"
        rm -rf "$1"
    fi

    return 0
}

# Run command before we begin
if [ "$PREBACKUP" ]; then
    echo ======================================================================
    echo "Prebackup command output."
    echo
    eval $PREBACKUP
    echo
    echo ======================================================================
    echo
fi

# Hostname for LOG information
if [ "$DBHOST" = "localhost" -o "$DBHOST" = "127.0.0.1" ]; then
    HOST=`hostname`
    if [ "$SOCKET" ]; then
        OPT="$OPT --socket=$SOCKET"
    fi
else
    HOST=$DBHOST
fi

# Try to select an available secondary for the backup or fallback to DBHOST (for mongo).
if [ "x${REPLICAONSLAVE}" == "xyes" ]; then
    # Return value via indirect-reference hack ...
    select_secondary_member secondary

    if [ -n "$secondary" ]; then
        DBHOST=${secondary%%:*}
        MONGOPORT=${secondary##*:}
    else
        SECONDARY_WARNING="WARNING: No suitable Secondary found in the Replica Sets.  Falling back to ${DBHOST}."
    fi
fi

echo ======================================================================
echo AutoDbBackup VER $VER

if [ ! -z "$SECONDARY_WARNING" ]; then
    echo
    echo "$SECONDARY_WARNING"
fi

echo
echo Backup of Database Server - $HOST on $DBHOST
echo ======================================================================

echo Backup Start `date`
echo ======================================================================
# Monthly Full Backup of all Databases
if [ $DOM = "01" ]; then
    echo Monthly Full Backup
    FILE="$BACKUPDIR/mongodb/monthly/Mongo$DATE.$M"
    MYFILE="$BACKUPDIR/mysql/monthly/Mysql$DATE.$M.sql"

# Weekly Backup
elif [ $DNOW = $DOWEEKLY ]; then
    echo Weekly Backup
    echo
    echo Rotating 5 weeks Backups...
    if [ "$W" -le 05 ]; then
        REMW=`expr 48 + $W`
    elif [ "$W" -lt 15 ]; then
        REMW=0`expr $W - 5`
    else
        REMW=`expr $W - 5`
    fi
	
    delete_objects "$BACKUPDIR/mongodb/weekly/Mongoweek.$REMW.*gpg"
    delete_objects "$BACKUPDIR/mysql/weekly/Mysqlweek.$REMW.*gpg" 

    rm -f $BACKUPDIR/mongodb/weekly/Mongoweek.$REMW.*
    rm -f $BACKUPDIR/mysql/weekly/Mysqlweek.$REMW.*
   echo
    FILE="$BACKUPDIR/mongodb/weekly/Mongoweek.$W.$DATE"
    MYFILE="$BACKUPDIR/mysql/weekly/Mysqlweek.$W.$DATE.sql"

# Daily Backup
else
    echo Daily Backup of Databases
    echo Rotating last weeks Backup...
    echo

    delete_objects "$BACKUPDIR/mongodb/daily/*.$DOW.*gpg"
    delete_objects "$BACKUPDIR/mysql/daily/*.$DOW.*gpg"    

    rm -f $BACKUPDIR/mongodb/daily/*.$DOW.*
    rm -f $BACKUPDIR/mysql/daily/*.$DOW.*
   echo
    FILE="$BACKUPDIR/mongodb/daily/Mongo$DATE.$DOW"
    MYFILE="$BACKUPDIR/mysql/daily/Mysql$DATE.$DOW.sql"
fi
dbdump $FILE && compression $FILE && upload $FILE
mydbdump $MYFILE && compression $MYFILE && upload $MYFILE
echo ----------------------------------------------------------------------
echo Backup End Time `date`
echo ======================================================================

echo Total disk space used for backup storage..
echo Size - Location
echo `du -hs "$BACKUPDIR/mongodb"`
echo `du -hs "$BACKUPDIR/mysql"`
echo
echo ======================================================================

# Run command when we're done
if [ "$POSTBACKUP" ]; then
    echo ======================================================================
    echo "Postbackup command output."
    echo
    eval $POSTBACKUP
    echo
    echo ======================================================================
fi

# Clean up IO redirection if we plan not to deliver log via e-mail.
[ ! "x$MAILCONTENT" == "xlog" ] && exec 1>&6 2>&7 6>&- 7>&-

if [ -s "$LOGERR" ]; then
    eval $SED "/^connected/d" "$LOGERR"
fi

if [ "$MAILCONTENT" = "log" ]; then
    cat "$LOGFILE" | mail -s "DB Backup Log for $HOST - $DATE" $MAILADDR

    if [ -s "$LOGERR" ]; then
        cat "$LOGERR"
        cat "$LOGERR" | mail -s "ERRORS REPORTED: DB Backup error Log for $HOST - $DATE" $MAILADDR
    fi
else
    if [ -s "$LOGERR" ]; then
        cat "$LOGFILE"
        echo
        echo "###### WARNING ######"
        echo "STDERR written to during mongodump or mysqldump execution."
        echo "The backup probably succeeded, as mongodump sometimes writes to STDERR, but you may wish to scan the error log below:"
        cat "$LOGERR"
    else
        cat "$LOGFILE"
    fi
fi

# TODO: Would be nice to know if there were any *actual* errors in the $LOGERR
STATUS=0
if [ -s "$LOGERR" ]; then
    STATUS=1
fi

# Clean up Logfile
rm -f "$LOGFILE" "$LOGERR"

exit $STATUS
