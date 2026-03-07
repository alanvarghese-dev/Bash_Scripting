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

DATA_DIR="${DATA_DIR:-/var/lib/process_monitor}"
METRICS_FILE="${METRICS_FILE:-/var/lib/process_monitor/metrics.prom}"
METRICS_FORMAT="${METRICS_FORMAT:-prometheus}"

if [[ ! -w "/var/lib/process_monitor" ]] 2>/dev/null; then
    DATA_DIR="./data"
    METRICS_FILE="./data/metrics.prom"
    mkdir -p "$DATA_DIR"
fi

SUDO=""
if docker ps &>/dev/null; then
    SUDO=""
elif [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
    echo "Note: Running with sudo for Docker access"
fi

collect_system_metrics() {
    local timestamp
    timestamp=$(date +%s)
    
    {
        echo "# HELP system_load_average System load average"
        echo "# TYPE system_load_average gauge"
        
        local load_avg
        load_avg=$(get_load_average)
        local load_1 load_5 load_15
        load_1=$(echo "$load_avg" | awk '{print $1}' | tr -d ',')
        load_5=$(echo "$load_avg" | awk '{print $2}' | tr -d ',')
        load_15=$(echo "$load_avg" | awk '{print $3}' | tr -d ',')
        
        echo "system_load_average{period=\"1m\"} ${load_1:-0} $timestamp"
        echo "system_load_average{period=\"5m\"} ${load_5:-0} $timestamp"
        echo "system_load_average{period=\"15m\"} ${load_15:-0} $timestamp"
        
        echo ""
        echo "# HELP system_cpu_usage System CPU usage percentage"
        echo "# TYPE system_cpu_usage gauge"
        
        local cpu_idle cpu_usage
        cpu_idle=$(get_cpu_idle)
        cpu_usage=$(echo "100 - ${cpu_idle:-100}" | bc 2>/dev/null || echo "0")
        
        echo "system_cpu_usage $cpu_usage $timestamp"
        
        echo ""
        echo "# HELP system_memory_usage System memory usage"
        echo "# TYPE system_memory_usage gauge"
        
        local mem_info
        mem_info=$(get_memory_info)
        IFS='|' read -r mem_total mem_used mem_free mem_percent <<< "$mem_info"
        
        echo "system_memory_total_bytes $mem_total $timestamp"
        echo "system_memory_used_bytes $mem_used $timestamp"
        echo "system_memory_free_bytes $mem_free $timestamp"
        
        echo ""
        echo "# HELP system_disk_usage System disk usage percentage"
        echo "# TYPE system_disk_usage gauge"
        
        local disk_usage
        disk_usage=$(get_disk_usage)
        
        echo "system_disk_usage{path=\"/\"} ${disk_usage:-0} $timestamp"
        
        echo ""
        echo "# HELP system_uptime System uptime in seconds"
        echo "# TYPE system_uptime gauge"
        
        local uptime_seconds
        uptime_seconds=$(get_uptime_seconds)
        echo "system_uptime $uptime_seconds $timestamp"
        
    } >> "$METRICS_FILE"
}

collect_process_metrics() {
    local timestamp
    timestamp=$(date +%s)
    
    {
        echo ""
        echo "# HELP process_info Process information"
        echo "# TYPE process_info gauge"
        
        for process in $MONITORED_PROCESSES; do
            local pids=($(pgrep -x "$process" 2>/dev/null || true))
            
            for pid in "${pids[@]:-}"; do
                [[ -z "$pid" ]] && continue
                
                local cpu mem state
                cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' || echo "0")
                mem=$(ps -p "$pid" -o %mem= 2>/dev/null | tr -d ' ' || echo "0")
                state=$(ps -p "$pid" -o state= 2>/dev/null | tr -d ' ' || echo "U")
                
                local comm
                comm=$(ps -p "$pid" -o comm= 2>/dev/null || echo "$process")
                
                echo "process_cpu_percent{pid=\"$pid\",name=\"$comm\"} ${cpu:-0} $timestamp"
                echo "process_memory_percent{pid=\"$pid\",name=\"$comm\"} ${mem:-0} $timestamp"
                echo "process_state{pid=\"$pid\",name=\"$comm\"} 1 $timestamp"
            done
            
            if [[ ${#pids[@]} -eq 0 ]]; then
                echo "process_running{name=\"$process\"} 0 $timestamp"
            else
                echo "process_running{name=\"$process\"} ${#pids[@]} $timestamp"
            fi
        done
        
    } >> "$METRICS_FILE"
}

rotate_metrics_file() {
    local max_size="${LOG_MAX_SIZE:-10485760}"
    
    if [[ -f "$METRICS_FILE" ]]; then
        local file_size
        file_size=$(stat -f%z "$METRICS_FILE" 2>/dev/null || stat -c%s "$METRICS_FILE" 2>/dev/null || echo "0")
        
        if (( file_size > max_size )); then
            mv "$METRICS_FILE" "${METRICS_FILE}.old"
            : > "$METRICS_FILE"
        fi
    fi
}

collect_container_metrics() {
    local timestamp
    timestamp=$(date +%s)
    
    {
        echo ""
        echo "# HELP container_status Container status"
        echo "# TYPE container_status gauge"
        echo "# HELP container_cpu_percent Container CPU usage percentage"
        echo "# TYPE container_cpu_percent gauge"
        echo "# HELP container_memory_percent Container memory usage percentage"
        echo "# TYPE container_memory_percent gauge"
        
        local server_file="${MONITOR_SERVERS_FILE:-./servers.txt}"
        
        if [[ -f "$server_file" ]]; then
            while IFS='|' read -r container hostname role; do
                [[ -z "$container" ]] && continue
                [[ "$container" =~ ^# ]] && continue
                
                local status cpu mem
                status="0"
                cpu="0"
                mem="0"
                
                if $SUDO docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
                    status="1"
                    cpu=$($SUDO docker stats --no-stream --format '{{.CPUPerc}}' "$container" 2>/dev/null | tr -d '%' || echo "0")
                    mem=$($SUDO docker stats --no-stream --format '{{.MemPerc}}' "$container" 2>/dev/null | tr -d '%' || echo "0")
                fi
                
                echo "container_status{container=\"$container\",hostname=\"$hostname\",role=\"$role\"} $status $timestamp"
                echo "container_cpu_percent{container=\"$container\",hostname=\"$hostname\",role=\"$role\"} ${cpu:-0} $timestamp"
                echo "container_memory_percent{container=\"$container\",hostname=\"$hostname\",role=\"$role\"} ${mem:-0} $timestamp"
                
            done < "$server_file"
        fi
        
    } >> "$METRICS_FILE"
}

export_json_format() {
    local json_file="${METRICS_FILE%.prom}.json"
    
    {
        echo "{"
        echo "  \"timestamp\": $(date +%s),"
        echo "  \"system\": {"
        
        local load_avg
        load_avg=$(get_load_average)
        local load_1
        load_1=$(echo "$load_avg" | awk '{print $1}' | tr -d ',')
        echo "    \"load_average\": ${load_1:-0},"
        
        local cpu_idle cpu_usage
        cpu_idle=$(get_cpu_idle)
        cpu_usage=$(echo "100 - ${cpu_idle:-100}" | bc 2>/dev/null || echo "0")
        echo "    \"cpu_usage\": ${cpu_usage:-0},"
        
        local disk_usage
        disk_usage=$(get_disk_usage)
        echo "    \"disk_usage\": ${disk_usage:-0}"
        echo "  },"
        echo "  \"processes\": ["
        
        local first=1
        for process in $MONITORED_PROCESSES; do
            local pids=($(pgrep -x "$process" 2>/dev/null || true))
            
            for pid in "${pids[@]:-}"; do
                [[ -z "$pid" ]] && continue
                
                local cpu mem
                cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' || echo "0")
                mem=$(ps -p "$pid" -o %mem= 2>/dev/null | tr -d ' ' || echo "0")
                
                [[ $first -eq 0 ]] && echo ","
                echo -n "    {\"name\": \"$process\", \"pid\": $pid, \"cpu\": ${cpu:-0}, \"mem\": ${mem:-0}}"
                first=0
            done
        done
        
        echo ""
        echo "  ]"
        echo "}"
        
    } > "$json_file"
}

main() {
    mkdir -p "$DATA_DIR"
    chmod 755 "$DATA_DIR"
    
    rotate_metrics_file
    
    case "$METRICS_FORMAT" in
        prometheus)
            collect_system_metrics
            collect_process_metrics
            if [[ "$CONTAINER_MONITORING_ENABLED" -eq 1 ]]; then
                collect_container_metrics
            fi
            ;;
        json)
            export_json_format
            ;;
        both)
            collect_system_metrics
            collect_process_metrics
            if [[ "$CONTAINER_MONITORING_ENABLED" -eq 1 ]]; then
                collect_container_metrics
            fi
            export_json_format
            ;;
    esac
}

main "$@"
