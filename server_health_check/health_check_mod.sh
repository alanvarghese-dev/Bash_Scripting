#!/bin/bash

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
report="report_$timestamp.txt"

exec > $report

echo "==========Server-Health-check========
"
echo "Date: $(date)"
echo ""

echo "CPU Usage:"
uptime
echo ""

echo "Memory Usage:"
free -h
echo ""

disk_usage=$(df / | tail -1 | awk '{print $5}' | tr -d '%')

echo "Disk Usage: $disk_usage%"

if [ $disk_usage -gt 80 ]
then
	echo "WARNING: Disk usage is above 80%"
fi
echo ""

echo "Logged in Users:"
who
echo ""

