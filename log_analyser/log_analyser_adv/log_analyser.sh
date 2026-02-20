#!/bin/bash

# log_analyzer.sh - Professional Log Analyzer with getopts (Enhanced)

# Color codes (ANSI escape sequences)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration File (e.g., config.ini) -  Allows for customizable settings
# [log]
# log_level = INFO
# [output]
# output_format = txt

# Usage function (with help message)
usage() {
    echo "Usage: $0 -f <log_file> [-s <keyword>] [-o <output_file>] [-l <log_level>]"
    echo "Options:"
    echo "  -f: Path to the log file to analyze (Required)"
    echo "  -s: Search for a specific keyword in the log file"
    echo "  -o: Save the analysis report to a file"
    echo "  -l: Log level to filter (INFO, WARNING, ERROR, DEBUG, FATAL)"
    echo "  -h: Display this help message"
    exit 1
}

# Load configuration (if config file exists) -  Example using `ini` parser
# if [ -f "config.ini" ]; then
#     source config.ini
# fi

# Default values (if not set in config)
LOG_FILE=""
SEARCH_KEY=""
OUTPUT_FILE=""
LOG_LEVEL="INFO"

# Parse arguments using getopts (with validation)
while getopts "f:s:o:l:h" opt; do
    case $opt in
        f) LOG_FILE=$OPTARG ;;
        s) SEARCH_KEY=$OPTARG ;;
        o) OUTPUT_FILE=$OPTARG ;;
        l) LOG_LEVEL=$OPTARG ;; # Validate log level
        h) usage ;;
        *) usage ;;
    esac
done

# Validate arguments
if [ -z "$LOG_FILE" ]; then
    echo -e "${RED}Error: Log file (-f) is required.${NC}"
    usage
fi

if [ ! -f "$LOG_FILE" ]; then
    echo -e "${RED}Error: File '$LOG_FILE' not found.${NC}"
    exit 1
fi

# Validate log level
if ! echo "$LOG_LEVEL" | grep -Eiq "^INFO$|^WARNING$|^ERROR$|^DEBUG$|^FATAL$" ; then
    echo -e "${RED}Error: Invalid log level.  Must be INFO, WARNING, ERROR, DEBUG or FATAL.${NC}"
    usage
fi


# 1. Define the analysis logic in a function (using functions for modularity)
analyze() {
    echo -e "${BLUE}--- Analysis Report for: $LOG_FILE ---${NC}"
    echo "Generated on: $(date)"
    echo -e "Total log entries: $(wc -l < "$LOG_FILE")"

    echo -e "\n${BLUE}--- Log Level Counts ---${NC}"
    echo -e "${GREEN}INFO:    $(grep -i "INFO" "$LOG_FILE" | wc -l)${NC}"
    echo -e "${YELLOW}WARNING: $(grep -i "WARNING" "$LOG_FILE" | wc -l)${NC}"
    echo -e "${RED}ERROR:   $(grep -i "ERROR" "$LOG_FILE" | wc -l)${NC}"
    echo -e "${BLUE}DEBUG:   $(grep -i "DEBUG" "$LOG_FILE" | wc -l)${NC}"
    echo -e "${RED}FATAL:   $(grep -i "FATAL" "$LOG_FILE" | wc -l)${NC}"

    echo -e "\n${RED}--- Top 5 Error Messages ---${NC}"
    # - awk '{ $1=$2=$3=""; print $0 }' removes date, time, and log level.
    grep -i "ERROR" "$LOG_FILE" | awk '{ $1=$2=$3=""; print $0 }' | sort | uniq -c | sort -nr | head -n 5

    echo -e "\n${GREEN}--- Top 5 Active Users ---${NC}"
    # Extracts the 5th field and deletes single quotes.
    grep -i "User" "$LOG_FILE" | awk '{ print $5 }' | tr -d "'" | sort | uniq -c | sort -nr | head -n 5

    if [ ! -z "$SEARCH_KEY" ]; then
        echo -e "\n${BLUE}--- Search Results for keyword: '$SEARCH_KEY' ---${NC}"
        grep -i "$SEARCH_KEY" "$LOG_FILE"
    fi

    echo -e "\n${BLUE}--- Entries for Log Level: '$LOG_LEVEL' ---${NC}"
    grep -i "$LOG_LEVEL" "$LOG_FILE"
}

# 4. Execute and handle output
if [ ! -z "$OUTPUT_FILE" ]; then
    analyze | tee "$OUTPUT_FILE"
    echo -e "\n${GREEN}Report saved to: $OUTPUT_FILE${NC}"
else
    analyze
fi

