#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"
JOBS_FILE="${SCRIPT_DIR}/jobs.txt"

source "$CONFIG_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

init_directories() {
    mkdir -p "$LOG_DIR" "$STATE_DIR"
}

load_servers() {
    if [[ -f "$SERVERS_FILE" ]]; then
        grep -v -E '^[[:space:]]*#|^[[:space:]]*$' "$SERVERS_FILE" 2>/dev/null || true
    fi
}

ssh_exec() {
    local server="$1"
    local port="$2"
    local cmd="$3"
    
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p "$port" -i "$SSH_KEY_PATH" "${SSH_USER}@127.0.0.1" "$cmd" 2>/dev/null || true
}

get_server_port() {
    local server="$1"
    local default_port=22
    
    case "$server" in
        server1) echo $((SSH_PORT_BASE)) ;;
        server2) echo $((SSH_PORT_BASE + 1)) ;;
        server3) echo $((SSH_PORT_BASE + 2)) ;;
        *) echo "$default_port" ;;
    esac
}

extract_job_name() {
    local cmd="$1"
    local name
    
    if [[ "$cmd" =~ ^/([^/]+) ]]; then
        name="${BASH_REMATCH[1]}"
    elif [[ "$cmd" =~ ^([^[:space:]]+) ]]; then
        name="${BASH_REMATCH[1]}"
    fi
    
    name="${name//[^a-zA-Z0-9_]/_}"
    echo "${name:0:50}"
}

discover_cron_jobs() {
    local servers
    servers=$(load_servers)
    
    for server in $servers; do
        server=$(echo "$server" | xargs)
        [[ -z "$server" ]] && continue
        
        local port
        port=$(get_server_port "$server")
        
        local crontab
        crontab=$(ssh_exec "$server" "$port" "crontab -l 2>/dev/null || true")
        
        if [[ -z "$crontab" ]] || [[ "$crontab" == "no crontab for"* ]]; then
            continue
        fi
        
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ "$line" =~ ^[[:space:]]*$ ]] && continue
            
            local schedule cmd job_name
            schedule=$(echo "$line" | awk '{print $1" "$2" "$3" "$4" "$5}')
            cmd=$(echo "$line" | sed 's/^[^ ]* [^ ]* [^ ]* [^ ]* [^ ]* //')
            
            job_name=$(extract_job_name "$cmd")
            job_name="${server}_${job_name}"
            
            add_job "$job_name" "$schedule" "$cmd" "$server"
        done <<< "$crontab"
    done
}

load_jobs() {
    local jobs=()
    local seen_jobs=()

    has_job() {
        local job_name="$1"
        for seen in "${seen_jobs[@]:-}"; do
            [[ "$seen" == "$job_name" ]] && return 0
        done
        return 1
    }

    add_job() {
        local job_name="$1"
        local job_schedule="$2"
        local job_command="$3"
        local job_server="${4:-local}"
        
        if ! has_job "$job_name"; then
            echo "$job_name|$job_schedule|$job_command|$job_server"
            seen_jobs+=("$job_name")
        fi
    }

    load_manual_jobs() {
        if [[ -f "$JOBS_FILE" ]]; then
            while IFS='|' read -r job_name job_schedule job_command; do
                job_name=$(echo "$job_name" | xargs)
                job_schedule=$(echo "$job_schedule" | xargs)
                job_command=$(echo "$job_command" | xargs)
                
                if [[ -n "$job_name" ]]; then
                    add_job "$job_name" "$job_schedule" "$job_command" "local"
                fi
            done < <(grep -v -E '^[[:space:]]*#|^[[:space:]]*$' "$JOBS_FILE" 2>/dev/null || true)
        fi
    }

    load_manual_jobs
    discover_cron_jobs
}

get_last_run() {
    local job_name="$1"
    local server="${2:-local}"
    local state_file="${STATE_DIR}/${server}_${job_name}.last_run"

    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    fi
}

save_last_run() {
    local job_name="$1"
    local server="${2:-local}"
    local timestamp="$3"
    local state_file="${STATE_DIR}/${server}_${job_name}.last_run"

    echo "$timestamp" > "$state_file"
}

get_job_status() {
    local job_name="$1"
    local job_command="$2"
    local job_schedule="$3"
    local server="${4:-local}"

    local last_run
    last_run=$(get_last_run "$job_name" "$server")

    local current_time
    current_time=$(date +%s)

    if [[ -z "$last_run" ]]; then
        echo "UNKNOWN - No previous run recorded"
        return 1
    fi

    local last_run_time
    last_run_time=$(date -d "$last_run" +%s 2>/dev/null) || last_run_time="$current_time"

    local time_diff=$((current_time - last_run_time))
    local minutes_late=$((time_diff / 60))

    if [[ $minutes_late -gt $MAX_MINUTES_LATE ]]; then
        echo "MISSED - Job is ${minutes_late} minutes overdue"
        return 1
    fi

    echo "OK - Last run: $last_run"
    return 0
}

send_alert() {
    local job_name="$1"
    local status="$2"
    local server="${3:-local}"
    local message="Cron Job Alert [$server]: $job_name - $status"

    log "ALERT: $message"

    if [[ -n "$ALERT_EMAIL" ]] && [[ "$ALERT_ON_FAILURE" == "true" ]]; then
        echo "$message" | mail -s "[CRON MONITOR] $job_name" "$ALERT_EMAIL" 2>/dev/null || true
    fi

    if [[ -n "$SLACK_WEBHOOK" ]]; then
        curl -s -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\"}" \
            "$SLACK_WEBHOOK" 2>/dev/null || true
    fi
}

check_job() {
    local job_name="$1"
    local job_command="$2"
    local job_schedule="$3"
    local server="${4:-local}"

    log "Checking job: $job_name (server: $server)"

    local status
    if get_job_status "$job_name" "$job_command" "$job_schedule" "$server"; then
        log "  Status: OK"
    else
        status=$?
        send_alert "$job_name" "$(get_job_status "$job_name" "$job_command" "$job_schedule" "$server" 2>&1)" "$server"
    fi
}

record_job_run() {
    local job_name="$1"
    local server="${2:-local}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    save_last_run "$job_name" "$server" "$timestamp"
    log "Recorded run for job: $job_name (server: $server) at $timestamp"
}

record_job_run_remote() {
    local job_name="$1"
    local server="$2"
    
    local port
    port=$(get_server_port "$server")
    
    local timestamp
    timestamp=$(ssh_exec "$server" "$port" "date '+%Y-%m-%d %H:%M:%S'")
    
    if [[ -n "$timestamp" ]]; then
        save_last_run "$job_name" "$server" "$timestamp"
        log "Recorded run for job: $job_name (server: $server) at $timestamp"
    fi
}

cleanup_old_logs() {
    if [[ -d "$LOG_DIR" ]]; then
        find "$LOG_DIR" -type f -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true
    fi
}

show_status() {
    echo "=== Cron Job Health Monitor Status ==="
    echo "Last Check: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "Monitored Jobs:"
    echo "----------------------------------------"

    while IFS='|' read -r job_name job_schedule job_command job_server; do
        job_name=$(echo "$job_name" | xargs)
        job_schedule=$(echo "$job_schedule" | xargs)
        job_command=$(echo "$job_command" | xargs)
        job_server=$(echo "$job_server" | xargs)

        if [[ -n "$job_name" ]]; then
            local last_run
            last_run=$(get_last_run "$job_name" "$job_server" || echo "Never")
            echo "  $job_name"
            echo "    Server: $job_server"
            echo "    Schedule: $job_schedule"
            echo "    Last Run: $last_run"
            echo ""
        fi
    done < <(load_jobs)
}

usage() {
    cat << EOF
Usage: $(basename "$0") [COMMAND]

Commands:
    check       Run health check on all jobs
    record      Record a job run (usage: record <job_name> [server])
    discover   Discover cron jobs from servers
    status      Show current status of all monitored jobs
    init        Initialize directories
    help        Show this help message

Examples:
    ./cron_health_monitor.sh check
    ./cron_health_monitor.sh record backup_job
    ./cron_health_monitor.sh record backup_job server1
    ./cron_health_monitor.sh discover

EOF
}

main() {
    local command="${1:-help}"

    init_directories

    case "$command" in
        check)
            log "Starting health check..."
            while IFS='|' read -r job_name job_schedule job_command job_server; do
                job_name=$(echo "$job_name" | xargs)
                job_server=$(echo "$job_server" | xargs)
                if [[ -n "$job_name" ]]; then
                    check_job "$job_name" "$job_command" "$job_schedule" "$job_server"
                fi
            done < <(load_jobs)
            cleanup_old_logs
            log "Health check complete"
            ;;
        record)
            if [[ -z "${2:-}" ]]; then
                log_error "Job name required for record command"
                exit 1
            fi
            record_job_run "$2" "${3:-local}"
            ;;
        discover)
            log "Discovering cron jobs..."
            while IFS='|' read -r job_name job_schedule job_command job_server; do
                job_name=$(echo "$job_name" | xargs)
                if [[ -n "$job_name" ]]; then
                    echo "Found: $job_name (server: $job_server)"
                    echo "  Schedule: $job_schedule"
                    echo "  Command: $job_command"
                    echo ""
                fi
            done < <(load_jobs)
            ;;
        status)
            show_status
            ;;
        init)
            init_directories
            log "Directories initialized"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"
