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

setup_directories() {
    log_info "Creating directories..."
    mkdir -p "$SCRIPT_DIR/ssh_keys"
    mkdir -p "$LOG_DIR"
    mkdir -p "$STATE_DIR"
    log_info "Directories created"
}

generate_ssh_keys() {
    log_info "Generating SSH keys..."
    
    if [[ -f "$SCRIPT_DIR/ssh_keys/id_rsa" ]]; then
        log_warn "SSH keys already exist, skipping generation"
        return 0
    fi
    
    ssh-keygen -t rsa -b 4096 -f "$SCRIPT_DIR/ssh_keys/id_rsa" -N "" -C "cron-monitor@host"
    chmod 600 "$SCRIPT_DIR/ssh_keys/id_rsa"
    chmod 644 "$SCRIPT_DIR/ssh_keys/id_rsa.pub"
    
    log_info "SSH keys generated"
}

start_containers() {
    log_info "Starting Docker containers..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    docker compose down 2>/dev/null || true
    docker compose up -d
    
    log_info "Waiting for containers to start..."
    sleep 5
    
    for i in 1 2 3; do
        local container="server$i"
        if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            log_error "Container $container failed to start"
            exit 1
        fi
    done
    
    log_info "All containers started"
}

verify_containers() {
    log_info "Verifying container setup..."
    
    for i in 1 2 3; do
        local container="server$i"
        
        log_info "Checking $container..."
        
        if ! docker exec "$container" pgrep -x "sshd" > /dev/null 2>&1; then
            log_warn "  SSH daemon not running in $container, attempting to start..."
            docker exec "$container" /usr/sbin/sshd 2>/dev/null || true
        fi
        
        if ! docker exec "$container" pgrep -x "cron" > /dev/null 2>&1; then
            log_warn "  Cron daemon not running in $container, attempting to start..."
            docker exec "$container" /usr/sbin/cron 2>/dev/null || true
        fi
        
        if ! docker exec "$container" test -f /root/.ssh/authorized_keys 2>/dev/null; then
            log_warn "  SSH keys not configured in $container..."
            docker exec "$container" mkdir -p /root/.ssh
            docker exec "$container" /bin/sh -c "cat /ssh_keys/id_rsa.pub >> /root/.ssh/authorized_keys"
            docker exec "$container" chmod 700 /root/.ssh
            docker exec "$container" chmod 600 /root/.ssh/authorized_keys
        fi
        
        log_info "  $container ready"
    done
    
    log_info "All containers verified"
}

wait_for_ssh() {
    log_info "Waiting for SSH to be ready..."
    
    local port=$SSH_PORT_BASE
    
    for i in 1 2 3; do
        local server="server$i"
        local server_port=$((port + i - 1))
        
        for attempt in {1..30}; do
            if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 -p "$server_port" -i "$SCRIPT_DIR/ssh_keys/id_rsa" "${SSH_USER}@127.0.0.1" "echo ok" &>/dev/null; then
                log_info "$server SSH is ready"
                break
            fi
            sleep 1
        done
    done
    
    log_info "SSH is ready on all servers"
}

init_directories() {
    log_info "Initializing monitor directories..."
    "$SCRIPT_DIR/cron_health_monitor.sh" init
}

show_status() {
    echo ""
    echo "=========================================="
    echo "         SETUP COMPLETE"
    echo "=========================================="
    echo ""
    echo "Servers running:"
    for i in 1 2 3; do
        local port=$((SSH_PORT_BASE + i - 1))
        echo "  - server$i: 127.0.0.1:$port"
    done
    echo ""
    echo "SSH Key: $SCRIPT_DIR/ssh_keys/id_rsa"
    echo "Config: $SCRIPT_DIR/config.conf"
    echo "Servers: $SCRIPT_DIR/servers.txt"
    echo ""
    echo "Next steps:"
    echo "  1. Test: ./test_monitor.sh"
    echo "  2. Check: ./cron_health_monitor.sh status"
    echo ""
}

main() {
    log_info "Starting Cron Job Health Monitor setup..."
    
    setup_directories
    generate_ssh_keys
    start_containers
    verify_containers
    wait_for_ssh
    init_directories
    show_status
    
    log_info "Setup complete!"
}

main "$@"
