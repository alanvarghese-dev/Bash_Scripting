#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

DATA_DIR="${DATA_DIR:-/var/lib/process_monitor}"
ALERT_LOG="${ALERT_LOG:-/var/log/process_monitor/alerts.log}"
ALERT_COOLDOWN="${ALERT_COOLDOWN:-300}"

if [[ ! -w "/var/lib/process_monitor" ]] 2>/dev/null; then
    DATA_DIR="./data"
    ALERT_LOG="./logs/alerts.log"
    mkdir -p "$DATA_DIR" "$(dirname "$ALERT_LOG")" 2>/dev/null || true
fi

check_cooldown() {
    local alert_key="$1"
    local cooldown_file="${DATA_DIR}/.alert_cooldown_${alert_key}"
    
    if [[ -f "$cooldown_file" ]]; then
        local last_alert
        last_alert=$(cat "$cooldown_file")
        local current_time
        current_time=$(date +%s)
        
        if (( current_time - last_alert < ALERT_COOLDOWN )); then
            return 1
        fi
    fi
    
    echo "$(date +%s)" > "$cooldown_file"
    return 0
}

log_alert() {
    local alert_type="$1"
    local message="$2"
    
    mkdir -p "$(dirname "$ALERT_LOG")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$alert_type] $message" >> "$ALERT_LOG"
}

send_email_alert() {
    local subject="$1"
    local body="$2"
    
    if [[ -z "$ALERT_EMAIL" ]] || [[ "$ALERT_EMAIL" == "admin@example.com" ]]; then
        return 0
    fi
    
    if command -v mail &>/dev/null; then
        echo "$body" | mail -s "$subject" "$ALERT_EMAIL"
    elif command -v sendmail &>/dev/null; then
        echo -e "Subject: $subject\n\n$body" | sendmail "$ALERT_EMAIL"
    fi
}

send_slack_alert() {
    local message="$1"
    
    if [[ -z "$SLACK_WEBHOOK" ]]; then
        return 0
    fi
    
    curl -s -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"$message\"}" \
        "$SLACK_WEBHOOK" 2>/dev/null || true
}

send_telegram_alert() {
    local message="$1"
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        return 0
    fi
    
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=$message" 2>/dev/null || true
}

send_alert() {
    local alert_type="$1"
    local message="$2"
    
    log_alert "$alert_type" "$message"
    send_email_alert "[ProcessMonitor] $alert_type" "$message"
    send_slack_alert "[ProcessMonitor] $alert_type: $message"
    send_telegram_alert "[ProcessMonitor] $alert_type: $message"
}

handle_process_alert() {
    local process_name="$1"
    local pid="$2"
    local cpu="$3"
    local mem="$4"
    local state="$5"
    
    local alert_key="process_${process_name}_${pid}"
    
    check_cooldown "$alert_key" || return 0
    
    local message="Process Alert: $process_name (PID: $pid)
CPU: ${cpu}%
Memory: ${mem}%
State: $state
Time: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_alert "PROCESS" "$message"
}

handle_system_alert() {
    local metric="$1"
    local value="$2"
    
    local alert_key="system_${metric}"
    
    check_cooldown "$alert_key" || return 0
    
    local message="System Alert: $metric
Value: $value
Time: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_alert "SYSTEM" "$message"
}

handle_container_alert() {
    local container="$1"
    local hostname="$2"
    local role="$3"
    local status="$4"
    local cpu="$5"
    local mem="$6"
    
    local alert_key="container_${container}"
    
    check_cooldown "$alert_key" || return 0
    
    local message="Container Alert: $container
Hostname: $hostname
Role: $role
Status: $status
CPU: ${cpu}%
Memory: ${mem}%
Time: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_alert "CONTAINER" "$message"
}

main() {
    local alert_category="$1"
    shift
    
    case "$alert_category" in
        process)
            local process_name="$1"
            local pid="$2"
            local cpu="$3"
            local mem="$4"
            local state="$5"
            handle_process_alert "$process_name" "$pid" "$cpu" "$mem" "$state"
            ;;
        system)
            local metric="$1"
            local value="$2"
            handle_system_alert "$metric" "$value"
            ;;
        container)
            local container="$1"
            local hostname="$2"
            local role="$3"
            local status="$4"
            local cpu="$5"
            local mem="$6"
            handle_container_alert "$container" "$hostname" "$role" "$status" "$cpu" "$mem"
            ;;
        *)
            echo "Usage: $0 {process|system|container} [args...]"
            exit 1
            ;;
    esac
}

main "$@"
