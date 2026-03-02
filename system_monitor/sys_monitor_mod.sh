#!/bin/bash

REPORT="system_report_$(date +%Y%m%d_%H%M%S).log"

{
	echo "===============System-Report========================"
	echo "Date: $(date)"
	echo ""

	echo "CPU Usage:"
	CPU_IDLE=$(top -bn1 | grep "Cpu" | awk '{print $8}')
	CPU_USAGE=$(echo "100 - $CPU_USAGE" | bc)
	echo "CPU Usage: $CPU_USAGE%"
	uptime
	if (( $(echo "$CPU_USAGE > 80" | bc -1) )); then
		echo "WARNING: CPU USAGE CRITICAL"
	echo ""

	echo "Memory Usage:"
	free -h
	echo ""

	echo "Disk Usage:"
	df -h
	echo ""

	echo "Top Processes:"
ps aux --sort=-%mem | head -n 6
echo ""


echo "----------------------------------------------------------------------------------------------"

} > $REPORT

echo "Report saved to $REPORT"


