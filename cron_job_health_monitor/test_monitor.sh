#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

source "$SCRIPT_DIR/config.conf"

run_ssh() {
    local port="$1"
    shift
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p "$port" -i "$SCRIPT_DIR/ssh_keys/id_rsa" "$@"
}

add_test_cron_jobs() {
    log_info "Adding test cron jobs to servers..."
    
    for i in 1 2 3; do
        local server="server$i"
        local port=$((SSH_PORT_BASE + i - 1))
        
        log_info "Adding cron jobs to $server..."
        
        run_ssh "$port" root@127.0.0.1 "echo '*/1 * * * * echo test_job_ok_$server >> /tmp/test_job.log' | crontab -" 2>/dev/null
        
        log_info "  Added: test_job_ok_$server (runs every minute)"
    done
    
    log_info "Test cron jobs added"
}

wait_for_jobs() {
    log_info "Waiting 70 seconds for cron jobs to run..."
    log_info "This allows the first cron job execution to complete..."
    
    local remaining=70
    while [[ $remaining -gt 0 ]]; do
        echo -ne "\r  Waiting: ${remaining}s remaining... "
        sleep 1
        ((remaining--))
    done
    echo ""
    
    log_info "Wait complete"
}

verify_jobs_ran() {
    log_info "Verifying cron jobs executed..."
    
    for i in 1 2 3; do
        local server="server$i"
        local port=$((SSH_PORT_BASE + i - 1))
        
        local output
        output=$(run_ssh "$port" "${SSH_USER}@127.0.0.1" "cat /tmp/test_job.log 2>/dev/null || echo 'NO_OUTPUT'" 2>/dev/null || echo "SSH_FAILED")
        
        echo "  $server: $output"
    done
    
    log_info "Verification complete"
}

run_health_check() {
    log_info "Running health check..."
    echo ""
    echo "========================================"
    "$SCRIPT_DIR/cron_health_monitor.sh" check
    echo "========================================"
    echo ""
}

show_discovered_jobs() {
    log_info "Discovered jobs:"
    echo ""
    "$SCRIPT_DIR/cron_health_monitor.sh" discover
    echo ""
}

cleanup_test_crons() {
    log_info "Cleaning up test cron jobs..."
    
    for i in 1 2 3; do
        local server="server$i"
        local port=$((SSH_PORT_BASE + i - 1))
        
        run_ssh "$port" "${SSH_USER}@127.0.0.1" "crontab -r 2>/dev/null || true" 2>/dev/null || true
        run_ssh "$port" "${SSH_USER}@127.0.0.1" "rm -f /tmp/test_job.log" 2>/dev/null || true
        
        log_info "  Cleaned $server"
    done
    
    log_info "Cleanup complete"
}

show_status() {
    log_info "Showing job status..."
    echo ""
    "$SCRIPT_DIR/cron_health_monitor.sh" status
    echo ""
}

main() {
    echo ""
    echo "=========================================="
    echo "    Cron Health Monitor Test Suite"
    echo "=========================================="
    echo ""
    
    log_info "Starting test..."
    
    add_test_cron_jobs
    wait_for_jobs
    verify_jobs_ran
    show_discovered_jobs
    run_health_check
    show_status
    cleanup_test_crons
    
    echo ""
    echo "=========================================="
    echo "         TEST COMPLETE"
    echo "=========================================="
    echo ""
    echo "Summary:"
    echo "  - Test cron jobs were added to all 3 servers"
    echo "  - Jobs ran for 70+ seconds"
    echo "  - Health check was performed"
    echo "  - Test cron jobs have been cleaned up"
    echo ""
    echo "To run the monitor manually:"
    echo "  ./cron_health_monitor.sh check"
    echo "  ./cron_health_monitor.sh status"
    echo ""
}

main "$@"
