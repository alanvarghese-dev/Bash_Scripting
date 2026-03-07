#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "  Process Monitoring System - Setup"
echo "========================================"
echo ""

check_dependencies() {
    echo "Checking dependencies..."
    
    local missing=()
    
    for cmd in ps pgrep top df uptime bc curl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Warning: Missing commands: ${missing[*]}"
        echo "Some features may not work correctly."
    fi
    
    echo "Dependency check complete."
}

create_directories() {
    echo ""
    echo "Creating directories..."
    
    local dirs=(
        "/var/log/process_monitor"
        "/var/lib/process_monitor"
        "/var/www/html/process_monitor"
        "/var/run"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ -w "$(dirname "$dir")" ]] || [[ "$(id -u)" -eq 0 ]]; then
            mkdir -p "$dir" 2>/dev/null || true
            echo "  Created: $dir"
        else
            echo "  Skipped (no write permission): $dir"
        fi
    done
}

set_permissions() {
    echo ""
    echo "Setting permissions..."
    
    chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true
    echo "  Made scripts executable"
    
    if [[ -w "/var/log/process_monitor" ]]; then
        chmod 755 /var/log/process_monitor 2>/dev/null || true
    fi
    
    if [[ -w "/var/lib/process_monitor" ]]; then
        chmod 755 /var/lib/process_monitor 2>/dev/null || true
    fi
}

validate_config() {
    echo ""
    echo "Validating configuration..."
    
    if [[ ! -f "$SCRIPT_DIR/config.conf" ]]; then
        echo "  Error: config.conf not found!"
        return 1
    fi
    
    source "$SCRIPT_DIR/config.conf"
    
    echo "  Configuration valid"
    echo "  Monitored processes: $MONITORED_PROCESSES"
    echo "  CPU threshold: $CPU_THRESHOLD%"
    echo "  Memory threshold: $MEMORY_THRESHOLD%"
    
    return 0
}

test_scripts() {
    echo ""
    echo "Testing scripts..."
    
    if "$SCRIPT_DIR/metrics.sh" 2>/dev/null; then
        echo "  Metrics: OK"
    else
        echo "  Metrics: Skipped (directories not writable)"
    fi
    
    if "$SCRIPT_DIR/dashboard.sh" 2>/dev/null; then
        echo "  Dashboard: OK"
    else
        echo "  Dashboard: Skipped (directories not writable)"
    fi
}

print_usage() {
    echo ""
    echo "========================================"
    echo "  Setup Complete!"
    echo "========================================"
    echo ""
    echo "Usage:"
    echo "  ./monitor.sh start    - Start monitoring"
    echo "  ./monitor.sh stop     - Stop monitoring"
    echo "  ./monitor.sh restart  - Restart monitoring"
    echo "  ./monitor.sh status   - Check status"
    echo ""
    echo "Configuration:"
    echo "  Edit config.conf to customize"
    echo "  - MONITORED_PROCESSES: Space-separated list"
    echo "  - CPU/MEMORY_THRESHOLD: Alert thresholds"
    echo "  - ALERT_EMAIL: Email for alerts"
    echo "  - SLACK_WEBHOOK: Slack notification URL"
    echo ""
    echo "Dashboard:"
    if [[ -w "/var/www/html/process_monitor" ]]; then
        echo "  Access: file:///var/www/html/process_monitor/index.html"
    else
        echo "  Run dashboard.sh to generate"
    fi
    echo ""
}

main() {
    check_dependencies
    create_directories
    set_permissions
    validate_config
    test_scripts
    print_usage
}

main "$@"
