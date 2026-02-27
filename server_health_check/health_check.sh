#!/bin/bash

echo "============SERVER HEALTH REPORT=============="
echo "Date: $(date)"
echo ""

echo "CPU Usage:"
uptime
echo ""

echo "Memory Usage:"
free -h
echo ""

echo "Disk Usage:"
df -h
echo ""


