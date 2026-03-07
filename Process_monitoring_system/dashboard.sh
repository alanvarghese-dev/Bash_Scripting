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

DASHBOARD_DIR="${DASHBOARD_DIR:-/var/www/html/process_monitor}"
DASHBOARD_REFRESH="${DASHBOARD_REFRESH:-30}"
DATA_DIR="${DATA_DIR:-/var/lib/process_monitor}"
LOCAL_DASHBOARD_DIR="${LOCAL_DASHBOARD_DIR:-./html}"

SUDO=""
if docker ps &>/dev/null; then
    SUDO=""
elif [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
    echo "Note: Running with sudo for Docker access"
fi

if [[ ! -w "$DASHBOARD_DIR" ]] && [[ -w "$LOCAL_DASHBOARD_DIR" ]]; then
    DASHBOARD_DIR="$LOCAL_DASHBOARD_DIR"
fi

get_system_data() {
    local load_avg load_1 load_5 load_15
    load_avg=$(get_load_average)
    load_1=$(echo "$load_avg" | awk '{print $1}' | tr -d ',')
    load_5=$(echo "$load_avg" | awk '{print $2}' | tr -d ',')
    load_15=$(echo "$load_avg" | awk '{print $3}' | tr -d ',')
    
    local cpu_idle cpu_usage
    cpu_idle=$(get_cpu_idle)
    cpu_usage=$(echo "100 - ${cpu_idle:-100}" | bc 2>/dev/null || echo "0")
    
    local disk_usage
    disk_usage=$(get_disk_usage)
    
    local mem_info mem_total mem_used mem_free mem_percent
    mem_info=$(get_memory_info)
    IFS='|' read -r mem_total mem_used mem_free mem_percent <<< "$mem_info"
    
    local mem_used_mb=$(( mem_used / 1024 / 1024 ))
    local mem_total_mb=$(( mem_total / 1024 / 1024 ))
    
    echo "$load_1|$load_5|$load_15|$cpu_usage|$disk_usage|$mem_used_mb|$mem_total_mb|$mem_percent"
}

get_container_data() {
    local container="$1"
    
    if ! $SUDO docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
        echo "stopped|0|0"
        return
    fi
    
    local status cpu mem
    status=$($SUDO docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
    
    if [[ "$status" != "running" ]]; then
        echo "stopped|0|0"
        return
    fi
    
    cpu=$($SUDO docker stats --no-stream --format '{{.CPUPerc}}' "$container" 2>/dev/null | tr -d '%' || echo "0")
    mem=$($SUDO docker stats --no-stream --format '{{.MemPerc}}' "$container" 2>/dev/null | tr -d '%' || echo "0")
    
    echo "running|$cpu|$mem"
}

get_containers_count() {
    local server_file="${MONITOR_SERVERS_FILE:-./servers.txt}"
    local count=0
    
    if [[ -f "$server_file" ]]; then
        while IFS='|' read -r container hostname role; do
            [[ -z "$container" ]] && continue
            [[ "$container" =~ ^# ]] && continue
            ((count++))
        done < "$server_file"
    fi
    
    echo "$count"
}

get_running_containers_count() {
    local server_file="${MONITOR_SERVERS_FILE:-./servers.txt}"
    local count=0
    
    if [[ -f "$server_file" ]]; then
        while IFS='|' read -r container hostname role; do
            [[ -z "$container" ]] && continue
            [[ "$container" =~ ^# ]] && continue
            
            if $SUDO docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
                ((count++))
            fi
        done < "$server_file"
    fi
    
    echo "$count"
}

generate_dashboard() {
    local html_file="${DASHBOARD_DIR}/index.html"
    
    mkdir -p "$DASHBOARD_DIR"
    
    local system_data
    system_data=$(get_system_data)
    IFS='|' read -r load_1 load_5 load_15 cpu_usage disk_usage mem_used_mb mem_total_mb mem_percent <<< "$system_data"
    
    local total_containers
    total_containers=$(get_containers_count)
    local running_containers
    running_containers=$(get_running_containers_count)
    
    {
        cat << 'DASHBOARD_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Process Monitor Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #1a1a2e; color: #eee; padding: 20px; }
        .container { max-width: 1400px; margin: 0 auto; }
        h1 { color: #00d9ff; margin-bottom: 20px; font-size: 28px; }
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
        .timestamp { color: #888; font-size: 14px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 20px; }
        .card { background: #16213e; border-radius: 10px; padding: 15px; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }
        .card h3 { color: #00d9ff; margin-bottom: 8px; font-size: 12px; text-transform: uppercase; }
        .value { font-size: 28px; font-weight: bold; }
        .value.warning { color: #ffc107; }
        .value.danger { color: #ff4757; }
        .value.success { color: #2ed573; }
        .sub { font-size: 12px; color: #888; margin-top: 5px; }
        .servers-section { background: #16213e; border-radius: 10px; padding: 20px; margin-bottom: 20px; }
        .servers-section h2 { color: #00d9ff; margin-bottom: 15px; }
        .server-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 15px; }
        .server-card { background: #0f3460; border-radius: 8px; padding: 15px; }
        .server-card.stopped { opacity: 0.6; }
        .server-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }
        .server-name { font-weight: bold; font-size: 16px; }
        .server-role { font-size: 11px; color: #888; background: #1a1a2e; padding: 2px 8px; border-radius: 4px; }
        .server-stats { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
        .stat { text-align: center; }
        .stat-label { font-size: 10px; color: #888; text-transform: uppercase; }
        .stat-value { font-size: 18px; font-weight: bold; }
        .status-running { color: #2ed573; }
        .status-stopped { color: #ff4757; }
        @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
        .live { animation: pulse 2s infinite; color: #00d9ff; }
        .summary { display: flex; gap: 20px; margin-bottom: 20px; }
        .summary-item { background: #16213e; padding: 10px 20px; border-radius: 8px; }
        .summary-value { font-size: 24px; font-weight: bold; }
        .summary-label { font-size: 12px; color: #888; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Container Monitor Dashboard <span class="live">● LIVE</span></h1>
            <div class="timestamp">Last updated: REPLACETIME</div>
        </div>
        
        <div class="summary">
            <div class="summary-item">
                <div class="summary-value REPLACERUNNINGCLASS">REPLACERUNNING/REPLACETOTAL</div>
                <div class="summary-label">Containers Running</div>
            </div>
            <div class="summary-item">
                <div class="summary-value REPLACECPUCLASS">REPLACECPU%</div>
                <div class="summary-label">Host CPU Usage</div>
            </div>
            <div class="summary-item">
                <div class="summary-value REPLACEMEMCLASS">REPLACEMEM%</div>
                <div class="summary-label">Host Memory Usage</div>
            </div>
            <div class="summary-item">
                <div class="summary-value REPLACEDISKCLASS">REPLACEDISK%</div>
                <div class="summary-label">Disk Usage</div>
            </div>
        </div>
        
        <div class="grid">
            <div class="card">
                <h3>Load Average (1m)</h3>
                <div class="value">REPLACELOAD1</div>
                <div class="sub">5m: REPLACELOAD5 | 15m: REPLACELOAD15</div>
            </div>
            <div class="card">
                <h3>Host CPU</h3>
                <div class="value REPLACECPUCLASS">REPLACECPU%</div>
            </div>
            <div class="card">
                <h3>Host Memory</h3>
                <div class="value REPLACEMEMCLASS">REPLACEMEM%</div>
                <div class="sub">REPLACEMEMUSED / REPLACEMEMTOTAL MB</div>
            </div>
            <div class="card">
                <h3>Disk</h3>
                <div class="value REPLACEDISKCLASS">REPLACEDISK%</div>
            </div>
        </div>
        
        <div class="servers-section">
            <h2>Monitored Containers (REPLACETOTAL total)</h2>
            <div class="server-grid">
DASHBOARD_EOF

    local server_file="${MONITOR_SERVERS_FILE:-./servers.txt}"
    
    if [[ -f "$server_file" ]]; then
        while IFS='|' read -r container hostname role; do
            [[ -z "$container" ]] && continue
            [[ "$container" =~ ^# ]] && continue
            
            local container_data
            container_data=$(get_container_data "$container")
            IFS='|' read -r status cpu mem <<< "$container_data"
            
            local status_class="running"
            [[ "$status" == "stopped" ]] && status_class="stopped"
            
            local cpu_class="success"
            local cpu_int="${cpu%.*}"
            [[ -n "$cpu_int" && "$cpu_int" -gt 80 ]] && cpu_class="danger"
            [[ -n "$cpu_int" && "$cpu_int" -gt 60 ]] && cpu_class="warning"
            
            local mem_class="success"
            local mem_int="${mem%.*}"
            [[ -n "$mem_int" && "$mem_int" -gt 80 ]] && mem_class="danger"
            [[ -n "$mem_int" && "$mem_int" -gt 60 ]] && mem_class="warning"
            
            echo "                <div class=\"server-card $status_class\">"
            echo "                    <div class=\"server-header\">"
            echo "                        <span class=\"server-name\">$container</span>"
            echo "                        <span class=\"server-role\">$role</span>"
            echo "                    </div>"
            echo "                    <div class=\"server-stats\">"
            echo "                        <div class=\"stat\">"
            echo "                            <div class=\"stat-label\">Status</div>"
            echo "                            <div class=\"stat-value status-$status_class\">$status</div>"
            echo "                        </div>"
            echo "                        <div class=\"stat\">"
            echo "                            <div class=\"stat-label\">CPU</div>"
            echo "                            <div class=\"stat-value $cpu_class\">${cpu:-0}%</div>"
            echo "                        </div>"
            echo "                        <div class=\"stat\">"
            echo "                            <div class=\"stat-label\">Memory</div>"
            echo "                            <div class=\"stat-value $mem_class\">${mem:-0}%</div>"
            echo "                        </div>"
            echo "                        <div class=\"stat\">"
            echo "                            <div class=\"stat-label\">Hostname</div>"
            echo "                            <div class=\"stat-value\">$hostname</div>"
            echo "                        </div>"
            echo "                    </div>"
            echo "                </div>"
        done < "$server_file"
    fi

    cat << 'DASHBOARD_EOF'
            </div>
        </div>
    </div>
    <script>
        setTimeout(() => window.location.reload(), REPLACEREFRESH000);
    </script>
</body>
</html>
DASHBOARD_EOF

    } | sed \
        -e "s|REPLACETIME|$(date '+%Y-%m-%d %H:%M:%S')|g" \
        -e "s|REPLACERUNNINGCLASS|$([[ ${running_containers:-0} -eq ${total_containers:-0} ]] && echo 'success' || echo 'warning')|g" \
        -e "s|REPLACECPUCLASS|$(echo "${cpu_usage:-0} > 80" | bc 2>/dev/null | grep -q 1 && echo 'danger' || (echo "${cpu_usage:-0} > 60" | bc 2>/dev/null | grep -q 1 && echo 'warning' || echo 'success'))|g" \
        -e "s|REPLACEMEMCLASS|$(echo "${mem_percent:-0} > 80" | bc 2>/dev/null | grep -q 1 && echo 'danger' || (echo "${mem_percent:-0} > 60" | bc 2>/dev/null | grep -q 1 && echo 'warning' || echo 'success'))|g" \
        -e "s|REPLACEDISKCLASS|$(echo "${disk_usage:-0} > 90" | bc 2>/dev/null | grep -q 1 && echo 'danger' || (echo "${disk_usage:-0} > 70" | bc 2>/dev/null | grep -q 1 && echo 'warning' || echo 'success'))|g" \
        -e "s|REPLACERUNNING|${running_containers:-0}|g" \
        -e "s|REPLACETOTAL|${total_containers:-0}|g" \
        -e "s|REPLACEREFRESH|${DASHBOARD_REFRESH:-30}|g" \
        -e "s|REPLACELOAD1|${load_1:-0}|g" \
        -e "s|REPLACELOAD5|${load_5:-0}|g" \
        -e "s|REPLACELOAD15|${load_15:-0}|g" \
        -e "s|REPLACECPU|${cpu_usage:-0}|g" \
        -e "s|REPLACEMEMUSED|${mem_used_mb:-0}|g" \
        -e "s|REPLACEMEMTOTAL|${mem_total_mb:-0}|g" \
        -e "s|REPLACEMEM|${mem_percent:-0}|g" \
        -e "s|REPLACEDISK|${disk_usage:-0}|g" \
        > "$html_file"
    
    chmod 644 "$html_file"
}

main() {
    generate_dashboard
    echo "Dashboard generated at: ${DASHBOARD_DIR}/index.html"
}

main "$@"
