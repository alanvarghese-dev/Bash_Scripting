#!/bin/bash

################################################################################
# Network Connectivity Monitoring Script
# 
# Purpose: Monitor network connectivity to multiple servers via SSH
#          by pinging 8.8.8.8 from each remote server
# 
# Usage: ./monitor_connectivity.sh
# 
# Requirements:
#   - hosts.txt file with list of server hostnames/IPs
#   - SSH key-based authentication configured
#   - ping command available on remote servers
#
# Output: connectivity_log.txt with timestamped results
################################################################################

# Set strict error handling
# -e: Exit immediately if a command exits with a non-zero status
# -u: Treat unset variables and parameters as an error
# -o pipefail: Returns the exit status of the leftmost command that failed
set -euo pipefail

################################################################################
# CONFIGURATION
################################################################################

# Get the directory where this script is located (for relative paths)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define file paths (relative to script directory)
HOSTS_FILE="${SCRIPT_DIR}/hosts.txt"
LOG_FILE="${SCRIPT_DIR}/connectivity_log.txt"

# SSH configuration
SSH_USER="root"                  # SSH username for connecting to servers
SSH_PORT="22"                    # SSH port (default: 22) - can be overridden by host:port format
SSH_TIMEOUT="10"                 # SSH connection timeout in seconds
SSH_KEY="${HOME}/.ssh/id_rsa"    # Path to SSH private key

# Ping configuration
PING_TARGET="8.8.8.8"            # Target IP to ping (Google DNS)
PING_COUNT="3"                   # Number of ping packets to send

# Color codes for output (optional - for better readability)
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_NC='\033[0m' # No Color

################################################################################
# FUNCTION: Print colored status messages
################################################################################
print_status() {
    local status="$1"
    local message="$2"
    
    case "$status" in
        "SUCCESS")
            echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_NC} $message"
            ;;
        "ERROR")
            echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $message"
            ;;
        "INFO")
            echo -e "${COLOR_YELLOW}[INFO]${COLOR_NC} $message"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

################################################################################
# FUNCTION: Log message to log file
################################################################################
log_result() {
    local host="$1"
    local status="$2"
    local timestamp="$3"
    
    # Write to log file in format: [TIMESTAMP] Host: HOSTNAME - Status: REACHABLE/UNREACHABLE
    echo "[$timestamp] Host: $host - Status: $status" >> "$LOG_FILE"
}

################################################################################
# FUNCTION: Check if host is reachable via SSH + ping
################################################################################
check_host_connectivity() {
    local host_input="$1"
    local timestamp="$2"
    
    # Parse host and port from input (support both "host" and "host:port" formats)
    local host="$host_input"
    local port="$SSH_PORT"
    
    if [[ "$host_input" == *:* ]]; then
        host="${host_input%%:*}"
        port="${host_input##*:}"
    fi
    
    # Full connection string for SSH
    local ssh_target="${SSH_USER}@${host}"
    
    # First, test if SSH connection is possible (without running ping)
    # This helps distinguish between SSH failure vs ping failure
    local ssh_error=""
    ssh_error=$(ssh -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o ConnectTimeout="${SSH_TIMEOUT}" \
          -o BatchMode=yes \
          -p "${port}" \
          "${ssh_target}" \
          "echo 'SSH_OK'" 2>&1) || true
    
    # Check if SSH connection itself failed
    if [[ ! "$ssh_error" == *"SSH_OK"* ]]; then
        # SSH connection failed - provide detailed error message
        if [[ "$VERBOSE" == "1" ]]; then
            print_status "ERROR" "SSH connection failed to ${ssh_target}:${port} - $ssh_error"
        else
            print_status "ERROR" "SSH connection failed to ${host_input}"
        fi
        log_result "$host_input" "SSH_FAILED" "$timestamp"
        echo "  ✗ $host_input - SSH FAILED"
        return 1
    fi
    
    # SSH connection successful, now run ping command
    # SSH into the remote server and run ping command
    # -o StrictHostKeyChecking=no: Auto-accept host key (for automation)
    # -o UserKnownHostsFile=/dev/null: Don't store host keys (for testing)
    # -o ConnectTimeout: Set connection timeout
    # -o BatchMode=yes: Disable password prompting (fail if key not available)
    
    if ssh -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o ConnectTimeout="${SSH_TIMEOUT}" \
          -o BatchMode=yes \
          -p "${port}" \
          "${ssh_target}" \
          "ping -c ${PING_COUNT} ${PING_TARGET} > /dev/null 2>&1" \
          2>/dev/null; then
        
        # Ping succeeded (exit code 0) - host is reachable
        log_result "$host_input" "REACHABLE" "$timestamp"
        echo "  ✓ $host_input - REACHABLE"
        return 0
    else
        # Ping failed (non-zero exit code) - host is unreachable
        log_result "$host_input" "UNREACHABLE" "$timestamp"
        echo "  ✗ $host_input - UNREACHABLE (network issue)"
        return 1
    fi
}

################################################################################
# FUNCTION: Validate prerequisites before starting
################################################################################
validate_prerequisites() {
    # Check if hosts.txt file exists
    if [[ ! -f "$HOSTS_FILE" ]]; then
        print_status "ERROR" "Hosts file not found: $HOSTS_FILE"
        exit 1
    fi
    
    # Check if hosts.txt is readable
    if [[ ! -r "$HOSTS_FILE" ]]; then
        print_status "ERROR" "Hosts file is not readable: $HOSTS_FILE"
        exit 1
    fi
    
    # Check if SSH key exists (optional warning)
    if [[ ! -f "$SSH_KEY" ]]; then
        print_status "ERROR" "SSH key not found: $SSH_KEY"
        print_status "INFO" "Please generate SSH key pair using: ssh-keygen -t rsa"
        exit 1
    fi
    
    # Check if hosts.txt is empty
    if [[ ! -s "$HOSTS_FILE" ]]; then
        print_status "ERROR" "Hosts file is empty: $HOSTS_FILE"
        exit 1
    fi
    
    print_status "INFO" "Prerequisites validated successfully"
}

################################################################################
# FUNCTION: Display usage information
################################################################################
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Network Connectivity Monitoring Tool

This script SSHs into each server listed in hosts.txt and checks network 
connectivity by pinging 8.8.8.8 (Google DNS) from each remote server.

Options:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output

Files:
    hosts.txt              List of servers to monitor (one per line)
    connectivity_log.txt   Output log file (created automatically)

Example hosts.txt format:
    server1.example.com
    192.168.1.10
    10.0.0.5

EOF
}

################################################################################
# MAIN SCRIPT EXECUTION
################################################################################

# Parse command line arguments
VERBOSE=0
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        *)
            print_status "ERROR" "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Print script header
echo "========================================"
echo "  Network Connectivity Monitor"
echo "========================================"
echo ""

# Step 1: Validate prerequisites (hosts.txt exists, SSH key available)
print_status "INFO" "Validating prerequisites..."
validate_prerequisites

# Step 2: Generate timestamp for this run
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
print_status "INFO" "Starting connectivity check at: $TIMESTAMP"
echo ""

# Step 3: Initialize counters for summary
total_hosts=0
reachable_hosts=0
unreachable_hosts=0

# Step 4: Read hosts from hosts.txt and check each one
# Using for loop to read lines from file
for host in $(cat "$HOSTS_FILE" | grep -v '^#' | grep -v '^$'); do
    
    # Trim whitespace from host string
    host=$(echo "$host" | xargs)
    
    # Skip empty lines or comments (lines starting with #)
    if [[ -z "$host" || "$host" == \#* ]]; then
        continue
    fi
    
    # Increment total hosts counter
    total_hosts=$((total_hosts + 1))
    
    # Display current host being checked
    echo "Checking host: $host"
    
    # Check connectivity for this host
    if check_host_connectivity "$host" "$TIMESTAMP"; then
        reachable_hosts=$((reachable_hosts + 1))
    else
        unreachable_hosts=$((unreachable_hosts + 1))
    fi
    
done

# Step 5: Display summary
echo ""
echo "========================================"
echo "  Summary"
echo "========================================"
echo "  Total hosts checked: $total_hosts"
echo "  Reachable:          $reachable_hosts"
echo "  Unreachable:        $unreachable_hosts"
echo "========================================"
echo ""

# Step 6: Log summary to file as well
echo "[$TIMESTAMP] Summary: $reachable_hosts/$total_hosts hosts reachable" >> "$LOG_FILE"

print_status "INFO" "Results logged to: $LOG_FILE"

# Exit with appropriate code
# 0 = all hosts reachable, 1 = some/all unreachable
if [[ $unreachable_hosts -eq 0 && $total_hosts -gt 0 ]]; then
    exit 0
else
    exit 1
fi
