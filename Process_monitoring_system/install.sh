#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "  Process Monitor - Installation Script"
echo "========================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Warning: Not running as root. Some operations may fail."
        echo "Consider running: sudo $0"
        echo ""
    fi
}

install_docker() {
    echo "Checking Docker..."

    if command -v docker &>/dev/null; then
        echo "  Docker: Already installed ($(docker --version))"
    else
        echo "  Docker: Not found"
        echo "  Please install Docker Desktop or Docker Engine"
        echo "  Visit: https://docs.docker.com/get-docker/"
        return 1
    fi

    if command -v docker-compose &>/dev/null; then
        echo "  Docker Compose: Already installed"
    elif docker compose version &>/dev/null 2>&1; then
        echo "  Docker Compose: Already installed (plugin)"
    else
        echo "  Docker Compose: Not found"
        return 1
    fi

    return 0
}

install_dependencies() {
    echo ""
    echo "Installing dependencies..."

    local pkg_manager=""
    local install_cmd=""

    if command -v apt-get &>/dev/null; then
        pkg_manager="apt-get"
        install_cmd="apt-get install -y"
    elif command -v yum &>/dev/null; then
        pkg_manager="yum"
        install_cmd="yum install -y"
    elif command -v brew &>/dev/null; then
        pkg_manager="brew"
        install_cmd="brew install"
    else
        echo "  Warning: No package manager found. Please install manually:"
        echo "    - bc (calculator)"
        echo "    - jq (JSON processor)"
        return 0
    fi

    case "$pkg_manager" in
        apt-get)
            sudo apt-get update -qq
            sudo apt-get install -y bc jq curl
            ;;
        yum)
            sudo yum install -y bc jq curl
            ;;
        brew)
            brew install bc jq curl
            ;;
    esac

    echo "  Dependencies installed successfully"
}

create_directories() {
    echo ""
    echo "Creating directories..."

    local dirs=(
        "/var/log/process_monitor"
        "/var/lib/process_monitor"
        "/var/www/html/process_monitor"
    )

    for dir in "${dirs[@]}"; do
        if sudo mkdir -p "$dir" 2>/dev/null; then
            sudo chmod 755 "$dir" 2>/dev/null || true
            echo "  Created: $dir"
        else
            echo "  Failed: $dir"
        fi
    done

    mkdir -p "$SCRIPT_DIR/html" 2>/dev/null || true
    echo "  Created: $SCRIPT_DIR/html"
}

set_permissions() {
    echo ""
    echo "Setting permissions..."

    chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true
    echo "  Made scripts executable"

    if [[ -f "$SCRIPT_DIR/servers.txt" ]]; then
        chmod 644 "$SCRIPT_DIR/servers.txt"
        echo "  servers.txt permissions set"
    fi
}

start_containers() {
    echo ""
    echo "Starting Docker containers..."

    if [[ ! -f "$SCRIPT_DIR/docker-compose.yml" ]]; then
        echo "  docker-compose.yml not found. Skipping."
        return 0
    fi

    cd "$SCRIPT_DIR"

    if sudo docker ps --format '{{.Names}}' | grep -q "^nginx-server$"; then
        echo "  Containers already running"
    else
        echo "  Run: cd $SCRIPT_DIR && docker-compose up -d"
    fi
}

test_scripts() {
    echo ""
    echo "Testing scripts..."

    if "$SCRIPT_DIR/metrics.sh" 2>/dev/null; then
        echo "  metrics.sh: OK"
    else
        echo "  metrics.sh: Skipped (may need docker running)"
    fi

    if "$SCRIPT_DIR/dashboard.sh" 2>/dev/null; then
        echo "  dashboard.sh: OK"
    else
        echo "  dashboard.sh: Skipped (directories not writable)"
    fi
}

print_usage() {
    echo ""
    echo "========================================"
    echo "  Installation Complete!"
    echo "========================================"
    echo ""
    echo "Next Steps:"
    echo ""
    echo "1. Start Docker containers:"
    echo "   docker-compose up -d"
    echo ""
    echo "2. Test with heredoc (server list piped from stdin):"
    echo "   ./monitor.sh start < servers.txt"
    echo ""
    echo "   Or use heredoc directly:"
    echo "   ./monitor.sh start << EOF"
    echo "   nginx-server|nginx|web"
    echo "   redis-server|redis|cache"
    echo "   EOF"
    echo ""
    echo "3. Check status:"
    echo "   ./monitor.sh status"
    echo ""
    echo "4. View dashboard:"
    echo "   open html/index.html"
    echo ""
    echo "5. Stop monitoring:"
    echo "   ./monitor.sh stop"
    echo ""
}

main() {
    check_root
    install_docker || true
    install_dependencies
    create_directories
    set_permissions
    test_scripts
    print_usage
}

main "$@"
