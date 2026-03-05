#!/bin/bash

# SSH Multi-Server Command Executor
# Author: DevOps Portfolio Project
# Description: Execute commands across multiple servers simultaneously

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG="$SCRIPT_DIR/servers.conf"
LOG_DIR="$SCRIPT_DIR/logs"
TIMEOUT=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to display help
show_help() {
    cat << EOF
SSH Multi-Server Command Executor

Usage: $0 [OPTIONS] "COMMAND"

OPTIONS:
    -f, --file FILE     Use custom servers configuration file (default: servers.conf)
    -t, --timeout SEC   SSH timeout in seconds (default: 30)
    -h, --help         Show this help message

EXAMPLES:
    $0 "uptime"                    # Check uptime on all servers
    $0 "df -h"                     # Check disk space
    $0 -f prod.conf "systemctl status nginx"  # Check nginx status on prod servers
    $0 -t 10 "whoami"              # Set 10 second timeout

CONFIGURATION:
    Edit servers.conf with format: name:hostname:port:username
    
EOF
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_DIR/execution.log"
}

# Function to create logs directory
setup_logging() {
    mkdir -p "$LOG_DIR"
    log_message "INFO" "=== SSH Multi-Server Execution Started ==="
}

# Function to read and parse server configuration
parse_servers() {
    local config_file="$1"
    local server_count=0
    
    log_message "INFO" "Reading server configuration from: $config_file"
    
    # Create a unique temporary file for servers list
    SERVERS_LIST_TMP=$(mktemp /tmp/ssh_multi_servers.XXXXXX)
    
    while IFS=':' read -r name hostname port username || [[ -n "$name" ]]; do
        [[ -z "$name" || "$name" =~ ^[[:space:]]*# ]] && continue
        
        # Clean whitespace
        name=$(echo "$name" | xargs)
        
        echo "$name:$hostname:$port:$username" >> "$SERVERS_LIST_TMP"
        server_count=$((server_count + 1))
        
        log_message "INFO" "Added server: $name ($hostname:$port@$username)"
    done < "$config_file"
    
    if [[ $server_count -eq 0 ]]; then
        echo -e "${RED}Error: No valid servers found in configuration file${NC}"
        [[ -f "$SERVERS_LIST_TMP" ]] && rm -f "$SERVERS_LIST_TMP"
        exit 1
    fi
    
    echo -e "${GREEN}Loaded $server_count servers from configuration${NC}"
}

# Function to execute SSH command on a single server
execute_ssh_command() {
    local server_name="$1"
    local server_info="$2"
    local command="$3"
    local timeout="$4"
    
    # Parse server info
    hostname=$(echo "$server_info" | cut -d: -f1)
    port=$(echo "$server_info" | cut -d: -f2)
    username=$(echo "$server_info" | cut -d: -f3)
    
    local result_file="/tmp/ssh_result_${server_name}.txt"
    local error_file="/tmp/ssh_error_${server_name}.txt"
    local pid_file="/tmp/ssh_pid_${server_name}.txt"
    
    {
        echo "=== $server_name ($hostname) ==="
        ssh -o ConnectTimeout="$timeout" \
            -o BatchMode=yes \
            -o StrictHostKeyChecking=no \
            -o LogLevel=ERROR \
            -p "$port" "$username@$hostname" "$command" 2>"$error_file"
        echo "EXIT_CODE:$?"
    } > "$result_file" 2>&1 &
    
    echo $! > "$pid_file"
}

# Function to collect results from all servers
collect_results() {
    local success_count=0
    local total_count=0
    
    echo
    echo -e "${BLUE}Results:${NC}"
    echo "========"
    
    while IFS=':' read -r server_name hostname port username || [[ -n "$server_name" ]]; do
        total_count=$((total_count + 1))
        
        local result_file="/tmp/ssh_result_${server_name}.txt"
        local error_file="/tmp/ssh_error_${server_name}.txt"
        local pid_file="/tmp/ssh_pid_${server_name}.txt"
        
        if [[ -f "$pid_file" ]]; then
            local pid=$(cat "$pid_file")
            wait "$pid" 2>/dev/null
            rm -f "$pid_file"
        fi
        
        if [[ -f "$result_file" ]]; then
            local exit_code=$(grep "EXIT_CODE:" "$result_file" | cut -d: -f2)
            
            if [[ "$exit_code" == "0" ]]; then
                echo -e "\n${GREEN}[OK] $server_name - SUCCESS${NC}"
                success_count=$((success_count + 1))
                log_message "INFO" "$server_name: Command executed successfully"
            else
                echo -e "\n${RED}[X] $server_name - FAILED (Exit code: $exit_code)${NC}"
                log_message "ERROR" "$server_name: Command failed with exit code $exit_code"
            fi
            
            grep -v "EXIT_CODE:" "$result_file" | head -20
            
            if [[ -f "$error_file" && -s "$error_file" ]]; then
                echo -e "${YELLOW}SSH Error: $(cat "$error_file")${NC}"
            fi
            rm -f "$result_file" "$error_file"
        else
            echo -e "\n${RED}[X] $server_name - NO RESPONSE${NC}"
            log_message "ERROR" "$server_name: No response received"
        fi
    done < "$SERVERS_LIST_TMP"
    
    echo
    echo "================================="
    echo -e "Summary: ${GREEN}$success_count${NC}/$total_count servers successful"
    log_message "INFO" "Execution completed: $success_count/$total_count successful"
    
    [[ -f "$SERVERS_LIST_TMP" ]] && rm -f "$SERVERS_LIST_TMP"
}

# Main execution function
main() {
    echo -e "${BLUE}SSH Multi-Server Command Executor${NC}"
    echo "=================================="
    echo -e "Command: ${YELLOW}$COMMAND${NC}"
    echo -e "Config:  ${YELLOW}$CONFIG_FILE${NC}"
    echo -e "Timeout: ${YELLOW}${TIMEOUT}s${NC}"
    echo
    
    parse_servers "$CONFIG_FILE"
    
    echo -e "${BLUE}Executing commands in parallel...${NC}"
    
    while IFS=':' read -r server_name hostname port username || [[ -n "$server_name" ]]; do
        execute_ssh_command "$server_name" "$hostname:$port:$username" "$COMMAND" "$TIMEOUT"
    done < "$SERVERS_LIST_TMP"
    
    echo "Waiting for all connections to complete..."
    # No need for arbitrary sleep, collect_results waits for PIDs
    
    collect_results
}

# Parse command line arguments
COMMAND=""
CONFIG_FILE="$DEFAULT_CONFIG"

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option $1"
            show_help
            exit 1
            ;;
        *)
            COMMAND="$1"
            shift
            ;;
    esac
done

if [[ -z "$COMMAND" ]]; then
    echo -e "${RED}Error: No command specified${NC}"
    show_help
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Error: Configuration file '$CONFIG_FILE' not found${NC}"
    exit 1
fi

setup_logging
main
