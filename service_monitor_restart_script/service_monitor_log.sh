#!/bin/bash

SERVICE="nginx"
LOGFILE="service_monitor.log"

STATUS=$( systemctl is-active $SERVICE)

if [ "$STATUS" != "active" ]
then
	echo "$(date) : $SERVICE was down. Restarted." >> $LOGFILE
	sudo systemctl restart $SERVICE
else
	echo "$(date) : $SERVICE is running. " >> $LOGFILE
fi

