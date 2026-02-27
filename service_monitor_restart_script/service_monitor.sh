#!/bin/bash

SERVICE="nginx"
STATUS=$( systemctl is-active $SERVICE )

if [ "$STATUS" != "active" ]
then
	echo "$SERVICE is down. Restarting..."
	sudo systemctl restart $SERVICE
else
	echo "$SERVICE is running. "
fi


