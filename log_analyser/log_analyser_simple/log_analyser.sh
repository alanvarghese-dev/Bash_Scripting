#!/bin/bash

# Script: log_analyser.sh
# Description: Parses a log file and provides counts for log levels (ERROR, WARNING, INFO)
#              along with a breakdown of specific messages.

# Usage: ./log_analyser.sh <log_file>

if [ $# -ne 1 ]; then
  echo "Usage: $0 logfile"
  exit 1
fi

LOG_FILE="$1"
LOG_LEVELS=("ERROR" "WARNING" "INFO")

if [ ! -f "$LOG_FILE" ]; then
  echo "Error: Log file '$LOG_FILE' does not exist."
  exit 1
fi

echo "--- Log Analysis Summary for: $LOG_FILE ---"

for LEVEL in "${LOG_LEVELS[@]}"; do
  COUNT=$(grep -ic "$LEVEL" "$LOG_FILE")
  echo -e "\n[$LEVEL] Total occurrences: $COUNT"

  if [ "$COUNT" -gt 0 ]; then
    echo "Top unique $LEVEL messages:"
    # Use grep to find the level (case-insensitive)
    # Use awk to skip the first three fields (date, time, level) and print the rest (the message)
    # Sort and count unique occurrences
    grep -i "$LEVEL" "$LOG_FILE" | awk '{$1=$2=$3=""; print $0}' | sed 's/^[ \t]*//' | sort | uniq -c | sort -rn | head -n 5
  fi
done

echo -e "\n--- End of Analysis ---"

exit 0
