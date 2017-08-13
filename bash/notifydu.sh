#!/bin/bash

# A script to notify disk usage on the root file system of a server on Slack

# Usage: notifydu "<webhook_url>" ["channel" "username"]
#      The webhook_url is mandatory
#      channel is optional and defaults to #jenkins
#      username is optional and defaults to Linode-Dev
#
# This script should be run by an hourly cron job.
# Add the following line to your /etc/crontab:
#
# 51 *    * * *   root    /opt/bin/notifydu <webhook_url>
#
# The script has the following behaviour:
# If root file system disk usage is below 80%:
#   Reports twice a day using a green Slack message
# If root file system disk usage is between 80% and 90%:
#   Reports four times a day using a warning Slack message
# If root file system disk usage is above 90%:
#   Reports every hour using a danger slack message
#

usage="notifydu \"<webhook_url>\" [\"channel\" \"username\"]"

# ------------ Slack variables ------------
webhook_url=$1
if [[ $webhook_url == "" ]]
then
    echo "Usage:"
    echo $usage
    exit 1
fi

channel=$2
if [[ $channel == "" ]]
then
    channel=#jenkins
fi

username=$3
if [[ $username == "" ]]
then
    username=Linode-Dev
fi
# Emojs to use on the slack messgage depending on disk usage
emoji_green=:innocent:
emoji_yellow=:frowning:
emoji_red=:angry:

# Disk usage thresholds 
threshold_disk_danger=90
threshold_disk_warn=80

# Current root filesystem disk usage in percent 
current_disk=$(df / | grep / | awk '{ print $5}' | sed 's/%//g')

# Current hour of the day (e.g. 08 or 13)
current_hour=$(date +"%H")

# Payload text to send (if any)
payload_text="Current disk usage: $current_disk%"
payload=""

# Evaluate if we have to send a message and which one
if [ "$current_disk" -lt "$threshold_disk_warn" ]
then
    # If disk usage is below 80% - only notify twice a day
    echo "Disk usage < 80%, current hour: $current_hour"
    case "$current_hour" in
    "11" | "23")
        payload="{\"channel\": \"$channel\", \"username\":\"$username\", \"icon_emoji\":\"$emoji_green\", \"attachments\":[{\"color\":\"good\" , \"text\": \"$payload_text\"}]}"
        ;;
    *)
        echo "No notification required"
        ;;
    esac
    
elif [ "$current_disk" -lt "$threshold_disk_danger" ]
then
    # If disk usage is between 80% and 90% - notify every 6 hours
    echo "Disk usage > 80% and < 90%, current hour: $current_hour"
    case "$current_hour" in
    "11" | "23" | "05" | "17")
        payload="{\"channel\": \"$channel\", \"username\":\"$username\", \"icon_emoji\":\"$emoji_yellow\", \"attachments\":[{\"color\":\"warning\" , \"text\": \"$payload_text\"}]}"
        ;;
    *)
        echo "No notification required"
        ;;
    esac
else
    #If disk usage is bigger than 90% - notify whenever executed
    echo "Disk usage > 90%"
    payload="{\"channel\": \"$channel\", \"username\":\"$username\", \"icon_emoji\":\"$emoji_red\", \"attachments\":[{\"color\":\"danger\" , \"text\": \"$payload_text\"}]}"
fi

# Send the slack message if payload is not empty
if [[ $payload != "" ]]
then
    echo "Sending slack message on disk usage..."
    escaped_payload=$(echo $payload | sed 's/"/\"/g' | sed "s/'/\'/g" )
    curl -s -d "$escaped_payload" $webhook_url
else
    echo "Payload is empty. No message to send"
fi
