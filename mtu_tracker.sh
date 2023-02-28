#!/usr/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${bash_source[0]}" )" &> /dev/null && pwd ) 
URL="my.autopi.io"
OUTPUT_FILE="mtu_logs.out.txt"
MTU_START=1472
MTU_END=1172
MTU=$MTU_START
INTERFACE="wwan0"
WORKING=false
DECREASE_BY=4
SLEEP_DURATION=10

while true; do
  packet_loss=$(ping -c 3 -s $MTU -M do -I $INTERFACE $URL | awk '/packet loss/{print $6}')
  datetime=$(date +"%Y-%m-%d %H:%M:%S")
  echo "$datetime - $URL MTU: $MTU ($((MTU+28))) packet loss: $packet_loss" >> $OUTPUT_FILE

  if $WORKING; then
    if [ -n "$packet_loss" ] && [ "$packet_loss" != "0%" ]; then
      WORKING=false
      echo "Packet loss detected. Running passive info gather and finding new MTU value." >> $OUTPUT_FILE
      $SCRIPT_DIR/gather_qmi_info.sh -p
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
      $SCRIPT_DIR/gather_qmi_info.sh -p
      MTU=$MTU_START
    fi
  fi
done