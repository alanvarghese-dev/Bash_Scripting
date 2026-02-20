#!/bin/bash

# log_analyzer.sh - Professional Log Analyzer with getopts

# Color codes (ANSI escape sequences)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "Usage: $0 -f <log_file> [-s <keyword>] [-o <output_file>]"
    echo "Options:"
    echo "  -f: Path to the log file to analyze (Required)"
    echo "  -s: Search for a specific keyword in the log file"
    echo "  -o: Save the analysis report to a file"
    exit 1
}

# 1. Parse arguments using getopts
# The ":" after a letter means it requires an argument (e.g., -f filename)
while getopts "f:s:o:" opt; do
    case $opt in
        f) LOG_FILE=$OPTARG ;;
        s) SEARCH_KEY=$OPTARG ;;
        o) OUTPUT_FILE=$OPTARG ;;
        *) usage ;;
    esac
done

# 2. Validation
if [ -z "$LOG_FILE" ]; then
    echo -e "${RED}Error: Log file (-f) is required.${NC}"
    usage
fi

if [ ! -f "$LOG_FILE" ]; then
    echo -e "${RED}Error: File '$LOG_FILE' not found.${NC}"
    exit 1
fi

# 3. Define the analysis logic in a function
# This makes it easier to redirect the output to both the screen and a file.
analyze() {
    echo -e "${BLUE}--- Analysis Report for: $LOG_FILE ---${NC}"
    echo "Generated on: $(date)"
    echo -e "Total log entries: $(wc -l < "$LOG_FILE")"
    
    echo -e "\n${BLUE}--- Log Level Counts ---${NC}"
    echo -e "${GREEN}INFO:    $(grep -c "INFO" "$LOG_FILE")${NC}"
    echo -e "${YELLOW}WARNING: $(grep -c "WARNING" "$LOG_FILE")${NC}"
    echo -e "${RED}ERROR:   $(grep -c "ERROR" "$LOG_FILE")${NC}"

    echo -e "\n${RED}--- Top 5 Error Messages ---${NC}"
    # - awk '{ $1=$2=$3=""; print $0 }' removes date, time, and log level.
    grep "ERROR" "$LOG_FILE" | awk '{ $1=$2=$3=""; print $0 }' | sort | uniq -c | sort -nr | head -n 5

    echo -e "\n${GREEN}--- Top 5 Active Users ---${NC}"
    # Extracts the 5th field and deletes single quotes.
    grep -i "User" "$LOG_FILE" | awk '{ print $5 }' | tr -d "'" | sort | uniq -c | sort -nr | head -n 5

    if [ ! -z "$SEARCH_KEY" ]; then
        echo -e "\n${BLUE}--- Search Results for: '$SEARCH_KEY' ---${NC}"
        grep -i "$SEARCH_KEY" "$LOG_FILE"
    fi
}

# 4. Execute and handle output
# If -o is provided, use 'tee' to show on screen AND save to the file.
if [ ! -z "$OUTPUT_FILE" ]; then
    analyze | tee "$OUTPUT_FILE"
    echo -e "\n${GREEN}Report saved to: $OUTPUT_FILE${NC}"
else
    analyze
fi
