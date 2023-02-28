#!/usr/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${bash_source[0]}" )" &> /dev/null && pwd ) 
URL="my.autopi.io"
OUTPUT_FILE=$SCRIPT_DIR/mtu.log
MTU_START=1472
MTU_END=1172
MTU=$MTU_START
INTERFACE="wwan0"
WORKING=false
DECREASE_BY=4
SLEEP_DURATION=30
MIN_REACHED_SLEEP_DURATION=300
QMI_INFO_SCRIPT_PATH=/home/pi/scripts/gather_qmi_info.sh

while getopts o:u: flag
do
    case "${flag}" in
      o) OUTPUT_FILE=${OPTARG};;
      u) URL=${OPTARG};;
    esac
done

echo "Output file: $OUTPUT_FILE"
echo "URL: $URL"

while true; do
  packet_loss=$(ping -c 3 -s $MTU -M do -I $INTERFACE $URL | awk '/packet loss/{print $6}')
  datetime=$(date +"%Y-%m-%d %H:%M:%S")
  echo "$datetime - $URL MTU: $MTU ($((MTU+28))) packet loss: $packet_loss" >> $OUTPUT_FILE

  if $WORKING; then
    if [ -n "$packet_loss" ] && [ "$packet_loss" != "0%" ]; then
      WORKING=false
      echo "Packet loss detected. Running passive info gather and finding new MTU value." >> $OUTPUT_FILE
      $QMI_INFO_SCRIPT_PATH -p -o /var/log/qmi-info_$(cat /etc/salt/minion_id)_$(date +"%d-%m-%Y_%H-%M-%S_%3N").out.txt
      MTU=$MTU_START
    else
      sleep $SLEEP_DURATION
    fi
  elif [ "$packet_loss" = "0%" ]; then
    echo "Working MTU value: $MTU ($((MTU+28)))" >> $OUTPUT_FILE
    WORKING=true
  else
    MTU=$((MTU-DECREASE_BY))
    if [ "$MTU" -lt "$MTU_END" ]; then
      echo "Minimum mtu value of $MTU ($((MTU+28))) reached. Resetting to $MTU_START ($((MTU_START+28))) and running passive info gather." >> $OUTPUT_FILE
      $QMI_INFO_SCRIPT_PATH -p -o /var/log/qmi-info_$(cat /etc/salt/minion_id)_$(date +"%d-%m-%Y_%H-%M-%S_%3N").out.txt
      MTU=$MTU_START
      sleep $MIN_REACHED_SLEEP_DURATION
    fi
  fi
done