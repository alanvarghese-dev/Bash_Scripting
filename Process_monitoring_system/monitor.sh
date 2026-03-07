#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

source "$SCRIPT_DIR/utils.sh"

LOG_DIR="${LOG_DIR:-/var/log/process_monitor}"
DATA_DIR="${DATA_DIR:-/var/lib/process_monitor}"
PID_FILE="${PID_FILE:-/var/run/process_monitor.pid}"

if [[ ! -w "/var/log/process_monitor" ]] 2>/dev/null; then
    LOG_DIR="./logs"
    DATA_DIR="./data"
    PID_FILE="./monitor.pid"
    mkdir -p "$LOG_DIR" "$DATA_DIR"
    echo "Note: Using local directories (./logs, ./data)"
fi

SUDO=""
DIR_SUDO=""

if docker ps &>/dev/null; then
    SUDO=""
elif [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
fi

if [[ -w "/var/log/process_monitor" ]] 2>/dev/null && [[ $EUID -ne 0 ]]; then
    DIR_SUDO="sudo"
fi

declare -A SERVERS

setup_directories() {
    $DIR_SUDO mkdir -p "$LOG_DIR" "$DATA_DIR"
    $DIR_SUDO chmod 755 "$LOG_DIR" "$DATA_DIR" 2>/dev/null || true
}

log_message() {
    local level="$1"
    shift
    local message="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_DIR/monitor.log"
}

read_servers_from_stdin() {
    local line
    while IFS='|' read -r container hostname role; do
        [[ -z "$container" ]] && continue
        [[ "$container" =~ ^# ]] && continue
        SERVERS["$container"]="$hostname|$role"
    done
}

read_servers_from_file() {
    local server_file="$1"
    if [[ -f "$server_file" ]]; then
        while IFS='|' read -r container hostname role; do
            [[ -z "$container" ]] && continue
            [[ "$container" =~ ^# ]] && continue
            SERVERS["$container"]="$hostname|$role"
        done < "$server_file"
    fi
}

get_container_stats() {
    local container="$1"
    
    if ! $SUDO docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
        echo "stopped|0|0|0"
        return
    fi
    
    local status cpu mem
    status=$($SUDO docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
    
    if [[ "$status" != "running" ]]; then
        echo "stopped|0|0|0"
        return
    fi
    
    cpu=$($SUDO docker stats --no-stream --format '{{.CPUPerc}}' "$container" 2>/dev/null | tr -d '%' || echo "0")
    mem=$($SUDO docker stats --no-stream --format '{{.MemPerc}}' "$container" 2>/dev/null | tr -d '%' || echo "0")
    
    echo "running|$cpu|$mem|0"
}

get_container_process_info() {
    local container="$1"
    local process="$2"
    
    if ! $SUDO docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
        return
    fi
    
    local pids
    pids=$($SUDO docker exec "$container" pgrep -x "$process" 2>/dev/null || true)
    
    for pid in $pids; do
        [[ -z "$pid" ]] && continue
        
        local cpu mem state
        cpu=$($SUDO docker exec "$container" ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' || echo "0")
        mem=$($SUDO docker exec "$container" ps -p "$pid" -o %mem= 2>/dev/null | tr -d ' ' || echo "0")
        state=$($SUDO docker exec "$container" ps -p "$pid" -o state= 2>/dev/null | tr -d ' ' || echo "U")
        
        echo "$container|$pid|$cpu|$mem|$state|$process"
    done
}

check_container_health() {
    local container="$1"
    local container_info="${SERVERS[$container]:-}"
    local hostname="${container_info%%|*}"
    local role="${container_info##*|}"
    
    local status cpu mem
    IFS='|' read -r status cpu mem _ <<< "$(get_container_stats "$container")"
    
    local alert_triggered=0
    
    if [[ "$status" != "running" ]]; then
        log_message "ERROR" "Container $container is not running!"
        alert_triggered=1
    else
        local cpu_int="${cpu%.*}"
        local mem_int="${mem%.*}"
        
        if [[ -n "$cpu_int" && "$cpu_int" -gt "$CONTAINER_CPU_THRESHOLD" ]]; then
            log_message "WARN" "Container $container CPU usage high: ${cpu}%"
            alert_triggered=1
        fi
        
        if [[ -n "$mem_int" && "$mem_int" -gt "$CONTAINER_MEM_THRESHOLD" ]]; then
            log_message "WARN" "Container $container Memory usage high: ${mem}%"
            alert_triggered=1
        fi
    fi
    
    if [[ $alert_triggered -eq 1 && "$ALERT_ENABLED" -eq 1 ]]; then
        "$SCRIPT_DIR/alert.sh" "container" "$container" "$hostname" "$role" "$status" "$cpu" "$mem"
    fi
}

check_all_containers() {
    for container in "${!SERVERS[@]}"; do
        check_container_health "$container"
    done
}

check_system_health() {
    local load_avg load_1
    load_1=$(get_load_average | awk '{print $1}' | tr -d ',')
    load_avg="${load_1%.*}"
    
    local cpu_idle cpu_usage
    cpu_idle=$(get_cpu_idle)
    cpu_usage=$(echo "100 - ${cpu_idle%.*}" | bc 2>/dev/null || echo "0")
    
    local disk_usage
    disk_usage=$(get_disk_usage)
    
    if [[ -n "$load_avg" ]]; then
        if [[ "$load_avg" -gt 4 ]]; then
            log_message "WARN" "High load average: $load_1"
            [[ "$ALERT_ENABLED" -eq 1 ]] && "$SCRIPT_DIR/alert.sh" "system" "load" "$load_1"
        fi
    fi
    
    if [[ "$cpu_usage" -gt "$CPU_THRESHOLD" ]]; then
        log_message "WARN" "High CPU usage: ${cpu_usage}%"
        [[ "$ALERT_ENABLED" -eq 1 ]] && "$SCRIPT_DIR/alert.sh" "system" "cpu" "$cpu_usage"
    fi
    
    if [[ "$disk_usage" -gt "$DISK_THRESHOLD" ]]; then
        log_message "WARN" "High disk usage: ${disk_usage}%"
        [[ "$ALERT_ENABLED" -eq 1 ]] && "$SCRIPT_DIR/alert.sh" "system" "disk" "$disk_usage"
    fi
}

collect_metrics() {
    if [[ "$METRICS_ENABLED" -eq 1 ]]; then
        "$SCRIPT_DIR/metrics.sh"
    fi
}

update_dashboard() {
    if [[ "$DASHBOARD_ENABLED" -eq 1 ]]; then
        "$SCRIPT_DIR/dashboard.sh"
    fi
}

monitor_loop() {
    log_message "INFO" "Process monitoring started"
    log_message "INFO" "Monitoring ${#SERVERS[@]} containers"
    
    for container in "${!SERVERS[@]}"; do
        log_message "INFO" "  - $container"
    done
    
    while true; do
        if [[ "$CONTAINER_MONITORING_ENABLED" -eq 1 ]]; then
            check_all_containers
        fi
        
        if [[ "$MONITOR_LOAD_AVG" -eq 1 ]] || [[ "$MONITOR_DISK" -eq 1 ]] || [[ "$MONITOR_CPU" -eq 1 ]]; then
            check_system_health
        fi
        
        collect_metrics
        update_dashboard
        
        sleep "$MONITOR_INTERVAL"
    done
}

cleanup() {
    log_message "INFO" "Stopping process monitor"
    [[ -f "$PID_FILE" ]] && rm -f "$PID_FILE"
    exit 0
}

daemonize() {
    setup_directories
    
    if ! $SUDO docker ps &>/dev/null; then
        echo "Error: Cannot access Docker. Please ensure:"
        echo "  - Docker is running"
        echo "  - User has docker permissions (run: sudo usermod -aG docker \$USER)"
        exit 1
    fi
    
    if [[ -f "$PID_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            echo "Monitor already running with PID: $old_pid"
            exit 1
        fi
    fi
    
    echo $$ > "$PID_FILE"
    
    trap cleanup SIGINT SIGTERM
    
    monitor_loop
}

status_check() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Monitor running with PID: $pid"
            echo ""
            echo "Monitored containers:"
            for container in "${!SERVERS[@]}"; do
                echo "  - $container"
            done
            return 0
        fi
    fi
    echo "Monitor not running"
    return 1
}

show_servers() {
    echo "Configured servers:"
    for container in "${!SERVERS[@]}"; do
        local info="${SERVERS[$container]}"
        local hostname="${info%%|*}"
        local role="${info##*|}"
        echo "  $container ($hostname) - $role"
    done
}

print_usage() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           PROCESS MONITORING SYSTEM - USAGE                  ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "USAGE: $0 <command> [options]"
    echo ""
    echo "COMMANDS:"
    echo "  start [file]   Start monitoring (from file or stdin)"
    echo "  stop          Stop monitoring"
    echo "  restart       Restart monitoring"
    echo "  status        Show monitoring status"
    echo "  servers       Show configured servers"
    echo "  help           Show this help message"
    echo ""
    echo "───────────────────────────────────────────────────────────────"
    echo "SERVER INPUT METHODS:"
    echo "───────────────────────────────────────────────────────────────"
    echo "  Method 1 - From file:"
    echo "    $0 start servers.txt"
    echo ""
    echo "  Method 2 - From pipe:"
    echo "    cat servers.txt | $0 start"
    echo ""
    echo "  Method 3 - From heredoc:"
    echo "    $0 start << EOF"
    echo "    nginx-server|nginx|web"
    echo "    redis-server|redis|cache"
    echo "    mysql-server|mysql|database"
    echo "    EOF"
    echo ""
    echo "───────────────────────────────────────────────────────────────"
    echo "SERVER FORMAT:"
    echo "───────────────────────────────────────────────────────────────"
    echo "  CONTAINER_NAME|HOSTNAME|ROLE"
    echo "  Example: nginx-server|nginx|web"
    echo ""
    echo "───────────────────────────────────────────────────────────────"
    echo "CONFIGURATION OPTIONS (config.conf):"
    echo "───────────────────────────────────────────────────────────────"
    echo "  MONITOR_INTERVAL           : Check interval in seconds (default: 5)"
    echo "  CPU_THRESHOLD              : Host CPU alert threshold % (default: 80)"
    echo "  MEMORY_THRESHOLD           : Host Memory alert threshold % (default: 80)"
    echo "  DISK_THRESHOLD             : Disk alert threshold % (default: 90)"
    echo "  CONTAINER_CPU_THRESHOLD    : Container CPU alert threshold % (default: 80)"
    echo "  CONTAINER_MEM_THRESHOLD    : Container Memory alert threshold % (default: 80)"
    echo "  ALERT_COOLDOWN             : Seconds between same alerts (default: 300)"
    echo "  ALERT_ENABLED              : Enable alerts (1=yes, 0=no)"
    echo "  METRICS_ENABLED            : Enable metrics (1=yes, 0=no)"
    echo "  DASHBOARD_ENABLED          : Enable dashboard (1=yes, 0=no)"
    echo "  DASHBOARD_REFRESH          : Dashboard auto-refresh seconds (default: 30)"
    echo ""
    echo "───────────────────────────────────────────────────────────────"
    echo "LOG LOCATIONS:"
    echo "───────────────────────────────────────────────────────────────"
    echo "  Monitor log : ./logs/monitor.log (or /var/log/process_monitor/monitor.log)"
    echo "  Alert log   : ./logs/alerts.log (or /var/log/process_monitor/alerts.log)"
    echo "  Metrics     : ./data/metrics.prom (or /var/lib/process_monitor/metrics.prom)"
    echo ""
    echo "───────────────────────────────────────────────────────────────"
    echo "DASHBOARD:"
    echo "───────────────────────────────────────────────────────────────"
    echo "  Local:   ./html/index.html"
    echo "  System:  /var/www/html/process_monitor/index.html"
    echo ""
    echo "───────────────────────────────────────────────────────────────"
    echo "QUICK START:"
    echo "───────────────────────────────────────────────────────────────"
    echo "  1. Edit servers.txt to add your containers"
    echo "  2. Start monitoring:  $0 start < servers.txt"
    echo "  3. View dashboard:    open html/index.html"
    echo "  4. Check status:      $0 status"
    echo "  5. Stop monitoring:   $0 stop"
    echo ""
}

main() {
    local command="${1:-start}"
    shift || true
    
    case "$command" in
        start)
            if [[ -p /dev/stdin ]] || [[ $# -gt 0 && "$1" != "-" ]]; then
                if [[ $# -gt 0 ]]; then
                    read_servers_from_file "$1"
                else
                    read_servers_from_stdin <&0
                fi
            else
                read_servers_from_file "${MONITOR_SERVERS_FILE:-./servers.txt}"
            fi
            
            if [[ ${#SERVERS[@]} -eq 0 ]]; then
                echo "Error: No servers configured!"
                echo "Use: $0 start < servers.txt"
                print_usage
                exit 1
            fi
            
            daemonize
            ;;
        stop)
            if [[ -f "$PID_FILE" ]]; then
                kill $(cat "$PID_FILE") 2>/dev/null && rm -f "$PID_FILE"
                echo "Monitor stopped"
            else
                echo "Monitor not running"
            fi
            ;;
        restart)
            "$0" stop
            sleep 2
            "$0" start "$@"
            ;;
        status)
            status_check
            ;;
        servers)
            if [[ $# -gt 0 ]]; then
                read_servers_from_file "$1"
            else
                read_servers_from_file "${MONITOR_SERVERS_FILE:-./servers.txt}"
            fi
            show_servers
            ;;
        help|--help|-h)
            print_usage
            ;;
        *)
            echo "Unknown command: $command"
            print_usage
            exit 1
            ;;
    esac
}

main "$@"
