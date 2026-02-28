#!/bin/bash

LOG_DIR="/home/iti/Automatic_log_Cleanup/logs"
RETENTION_DAYS=7
REPORT="cleanup_report.log"

echo "------ Log Cleanup Report $(date) ---------"

FILES=$(find $LOG_DIR -name "*.log" -type f -mtime +$RETENTION_DAYS)

count=0

if [ -z "$FILES" ]
then
	echo "No old log files found." >> $REPORT
else
for file in $FILES
do 
	echo  "Deleting $file" >> $REPORT
	rm -f $file
	COUNT=$((COUNT+1))
done
echo "$COUNT files deleted." >> $REPORT
fi
echo "---------------------------------------------------" >> $REPORT

