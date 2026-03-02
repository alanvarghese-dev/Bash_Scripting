#!/bin/bash

echo "============System Resource Monitor==============="
echo "Date: $(date)"
echo ""

echo "CPU Usage:"
top -bn1 | grep "Cpu"
echo ""



echo "Memory Usage:"
free -h
echo ""

echo "Disk Usage:"
df -h
echo ""

echo "Top 5 processes by Memory:"
ps aux --sort=-%mem | head -n 6
echo""
echo "--------------------------------------------------"
