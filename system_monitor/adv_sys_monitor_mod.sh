#!/bin/bash

REPORT="logs/system_report_$(date +%Y%m%d_%H%M%S).log"

{
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'



	echo "===============System-Report========================"
	echo "Date: ($date)"
	echo ""

	echo "CPU Usage:"
	CPU_IDLE="$(top -bn1 | grep "Cpu" | awk '{print $8}')"
	CPU_USAGE="$(echo "100 - $CPU_IDLE" | bc -l)"
	echo -e "${YELLOW}CPU Usage: $CPU_USAGE%"
	uptime

	if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
		echo -e "${RED}WARNING: CPU USAGE CRITICAL${NC}"
	elif (( $(echo "$CPU_USAGE > 60" | bc -l) )); then
		echo -e "${YELLOW}CPU usage getting high${NC}"
	else
		echo -e "${GREEN}CPU usage Normal${NC}"

	fi	
	echo ""

	echo "Memory Usage:"
	MEM_USAGE="$(free -h | awk '/Mem/{printf("%.2f"), $3/$2 * 100}')"
	if (( $(echo "$MEM_USAGE > 80" | bc -l) )); then
		echo -e "${RED}WARNING: MEMORY USAGE CRITICAL${NC}"
	elif (( $(echo "$MEM_USAGE > 60" | bc -l) )); then
		echo -e "${YELLOW}Memory usage high${NC}"
	else
		echo -e "${GREEN}Memory usage Normal${NC}"
	fi
	echo ""

	echo "Disk Usage:"
	DISK_USAGE="$(df / | awk 'NR==2 {print $5}' | sed 's/%//')"
	if (( $(echo "$DISK_USAGE > 80" | bc) )); then
	echo -e  "${RED}WARNING: DISK SPACE CRITICAL${NC}"
elif (( $(echo "$DISK_USAGE > 60 " | bc) )); then
echo -e	"${YELLOW}Disk space getting full${NC}"
else 
	echo -e "${GREEN}Disk usage Normal${NC}"
	fi
	echo ""

	echo "Top Processes:"
ps aux --sort=-%mem | head -n 6
echo ""


echo "----------------------------------------------------------------------------------------------"

} | tee  > $REPORT

echo "Report saved to $REPORT"


