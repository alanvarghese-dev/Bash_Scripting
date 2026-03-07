#!/usr/bin/env bash
set -euo pipefail

OS_TYPE=""
OS_NAME=""

detect_os() {
    if [[ "$(uname)" == "Darwin" ]]; then
        OS_TYPE="macos"
        OS_NAME="macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_TYPE="linux"
        OS_NAME="${ID:-linux}"
    else
        OS_TYPE="linux"
        OS_NAME="unknown"
    fi
    export OS_TYPE OS_NAME
}

get_cpu_idle() {
    if [[ "$OS_TYPE" == "macos" ]]; then
        top -l 1 -n 0 2>/dev/null | grep "CPU usage" | awk '{print $5}' | tr -d '%'
    else
        local cpu_line
        cpu_line=$(top -bn 1 | grep "Cpu(s)")
        if [[ -n "$cpu_line" ]]; then
            echo "$cpu_line" | awk '{print $8}' | tr -d '%id,'
        else
            grep "cpu " /proc/stat | awk '{usage=($2+$3+$4+$7+$8)/($2+$3+$4+$5+$6+$7+$8)*100; print 100-usage}'
        fi
    fi
}

get_load_average() {
    if [[ "$OS_TYPE" == "macos" ]]; then
        uptime | awk -F'load average:' '{print $2}' | awk '{print $1, $2, $3}'
    else
        uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1, $2, $3}'
    fi
}

get_memory_info() {
    local mem_total mem_used mem_free mem_percent
    
    if [[ "$OS_TYPE" == "macos" ]]; then
        mem_total=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
        local page_size
        page_size=$(sysctl -n vm.pagesize 2>/dev/null || echo "4096")
        local pages_active pages_wire pages_free
        pages_active=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.')
        pages_wire=$(vm_stat | grep "Pages wired down:" | awk '{print $4}' | tr -d '.')
        pages_free=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
        mem_used=$(( (pages_active + pages_wire) * page_size ))
        mem_free=$(( pages_free * page_size ))
        mem_percent=$(( mem_used * 100 / mem_total ))
    else
        if [[ -f /proc/meminfo ]]; then
            local mem_total_kb mem_available_kb mem_free_kb
            mem_total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
            mem_available_kb=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}')
            if [[ -n "$mem_available_kb" ]]; then
                mem_free_kb=$mem_available_kb
            else
                mem_free_kb=$(grep MemFree /proc/meminfo | awk '{print $2}')
                local buffers cached
                buffers=$(grep Buffers /proc/meminfo | awk '{print $2}')
                cached=$(grep "^Cached" /proc/meminfo | awk '{print $2}')
                mem_free_kb=$(( mem_free_kb + buffers + cached ))
            fi
            mem_total=$(( mem_total_kb * 1024 ))
            mem_free=$(( mem_free_kb * 1024 ))
            mem_used=$(( mem_total - mem_free ))
            mem_percent=$(( (mem_total_kb - mem_free_kb) * 100 / mem_total_kb ))
        else
            mem_total=0
            mem_used=0
            mem_free=0
            mem_percent=0
        fi
    fi
    
    echo "${mem_total}|${mem_used}|${mem_free}|${mem_percent}"
}

get_disk_usage() {
    df -h / | tail -1 | awk '{print $5}' | tr -d '%'
}

get_uptime_seconds() {
    if [[ "$OS_TYPE" == "macos" ]]; then
        local boot_time
        boot_time=$(sysctl -n kern.boottime 2>/dev/null | grep -oE '[0-9]+' | head -1)
        if [[ -n "$boot_time" ]]; then
            echo $(( $(date +%s) - boot_time ))
        else
            echo "0"
        fi
    else
        if [[ -f /proc/uptime ]]; then
            awk '{print int($1)}' /proc/uptime
        else
            echo "0"
        fi
    fi
}

detect_os