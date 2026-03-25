#!/bin/bash
# =============================================================================
# System Update Manager
# =============================================================================
# Purpose: Automated system update management for Debian/Ubuntu systems
#          Checks for updates, installs them, tracks history, and provides
#          rollback capability
# Author: DevOps Team
# Version: 1.0.0
# License: MIT
# Usage: ./update_manager.sh [OPTIONS]
# =============================================================================

set -euo pipefail

# =============================================================================
# Exit Codes
# =============================================================================
readonly E_SUCCESS=0
readonly E_ERROR=1
readonly E_PERMISSION=2
readonly E_LOCK=3
readonly E_UPDATE=4
readonly E_ROLLBACK=5
readonly E_CONFIG=6
readonly E_NETWORK=7
readonly E_DISK=8

# =============================================================================
# Global Variables
# =============================================================================
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="1.0.0"

# Default paths (overridable via config)
CONFIG_FILE="${SCRIPT_DIR}/config.ini"
LOG_FILE="/var/log/update_manager.log"
DB_PATH="/var/lib/update_manager/history.db"
BACKUP_DIR="/var/lib/update_manager/backups"
ROLLBACK_DIR="/var/lib/update_manager/rollback"
LOCK_FILE="/var/lock/update_manager.lock"

# Default settings (overridable via config)
DIST_UPGRADE=false
AUTO_REMOVE=true
CLEAN_CACHE=true
MAX_RETRIES=3
TIMEOUT=300

# Colors for terminal output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Temporary files (cleaned up on exit)
TEMP_DIR=""
LOCK_FD=""

# =============================================================================
# Logging Functions
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}" 2>/dev/null || true
}

log_info() {
    log "INFO" "$@"
}

log_warning() {
    log "WARNING" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        log "DEBUG" "$@"
    fi
}

log_to_syslog() {
    local priority="$1"
    shift
    local message="$*"
    
    if command -v logger &>/dev/null; then
        logger -t "update_manager" -p "${priority}" "${message}" 2>/dev/null || true
    fi
}

# =============================================================================
# Configuration Functions
# =============================================================================

parse_config_value() {
    local key="$1"
    local default="$2"
    local value
    
    value=$(grep "^${key}" "${CONFIG_FILE}" 2>/dev/null | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [[ -z "${value}" ]]; then
        echo "${default}"
    else
        echo "${value}"
    fi
}

parse_config_bool() {
    local key="$1"
    local default="$2"
    local value
    
    value=$(parse_config_value "${key}" "${default}")
    
    case "${value}" in
        true|yes|1|enabled|on)
            echo "true"
            ;;
        *)
            echo "false"
            ;;
    esac
}

load_config() {
    log_info "Loading configuration from ${CONFIG_FILE}..."
    
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log_warning "Configuration file not found: ${CONFIG_FILE}"
        log_warning "Using default settings"
        return 0
    fi
    
    if [[ ! -r "${CONFIG_FILE}" ]]; then
        log_error "Cannot read configuration file: ${CONFIG_FILE}"
        exit ${E_CONFIG}
    fi
    
    LOG_FILE=$(parse_config_value "log_file" "${LOG_FILE}")
    DB_PATH=$(parse_config_value "db_path" "${DB_PATH}")
    BACKUP_DIR=$(parse_config_value "backup_dir" "${BACKUP_DIR}")
    ROLLBACK_DIR=$(parse_config_value "rollback_dir" "${ROLLBACK_DIR}")
    LOCK_FILE=$(parse_config_value "lock_file" "${LOCK_FILE}")
    
    DIST_UPGRADE=$(parse_config_bool "dist_upgrade" "${DIST_UPGRADE}")
    AUTO_REMOVE=$(parse_config_bool "auto_remove" "${AUTO_REMOVE}")
    CLEAN_CACHE=$(parse_config_bool "clean_cache" "${CLEAN_CACHE}")
    
    MAX_RETRIES=$(parse_config_value "max_retries" "${MAX_RETRIES}")
    TIMEOUT=$(parse_config_value "timeout" "${TIMEOUT}")
    
    log_info "Configuration loaded successfully"
}

# =============================================================================
# Pre-flight Check Functions
# =============================================================================

validate_bash_version() {
    local major minor
    
    IFS='.' read -r major minor <<< "${BASH_VERSION}"
    
    if [[ "${major}" -lt 4 ]]; then
        log_error "Bash version 4.0 or higher is required (found ${BASH_VERSION})"
        exit ${E_ERROR}
    fi
    
    log_debug "Bash version: ${BASH_VERSION}"
}

check_os_compatibility() {
    local os_id os_version
    
    log_info "Checking OS compatibility..."
    
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS: /etc/os-release not found"
        exit ${E_ERROR}
    fi
    
    os_id=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
    os_version=$(grep "^VERSION_ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
    
    case "${os_id}" in
        ubuntu|debian)
            log_info "Detected ${os_id} ${os_version}"
            ;;
        *)
            log_warning "Untested OS: ${os_id} ${os_version}"
            log_warning "This script is designed for Debian/Ubuntu systems"
            ;;
    esac
}

check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script requires root privileges"
        log_error "Please run with: sudo ${SCRIPT_NAME}"
        exit ${E_PERMISSION}
    fi
    log_debug "Running as root"
}

check_required_commands() {
    local commands=("apt-get" "dpkg" "sqlite3" "md5sum")
    local missing=()
    
    for cmd in "${commands[@]}"; do
        if ! command -v "${cmd}" &>/dev/null; then
            missing+=("${cmd}")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        log_error "Install with: apt-get install ${missing[*]}"
        exit ${E_ERROR}
    fi
    
    log_debug "All required commands available"
}

check_disk_space() {
    local required_mb=500
    local available_kb
    local available_mb
    
    available_kb=$(df -k /var | awk 'NR==2 {print $4}')
    available_mb=$((available_kb / 1024))
    
    if [[ ${available_mb} -lt ${required_mb} ]]; then
        log_error "Insufficient disk space: ${available_mb}MB available, ${required_mb}MB required"
        exit ${E_DISK}
    fi
    
    log_debug "Disk space OK: ${available_mb}MB available"
}

# =============================================================================
# Lock Management Functions
# =============================================================================

acquire_lock() {
    log_info "Acquiring lock..."
    
    local lock_dir
    lock_dir=$(dirname "${LOCK_FILE}")
    
    if [[ ! -d "${lock_dir}" ]]; then
        mkdir -p "${lock_dir}" 2>/dev/null || {
            log_error "Cannot create lock directory: ${lock_dir}"
            exit ${E_ERROR}
        }
    fi
    
    exec 200>"${LOCK_FILE}"
    
    if ! flock -n 200; then
        log_error "Another instance is already running (lock file: ${LOCK_FILE})"
        log_error "If you're sure no other instance is running, remove: ${LOCK_FILE}"
        exit ${E_LOCK}
    fi
    
    LOCK_FD=200
    log_debug "Lock acquired"
}

release_lock() {
    if [[ -n "${LOCK_FD}" ]]; then
        flock -u "${LOCK_FD}" 2>/dev/null || true
    fi
    
    if [[ -f "${LOCK_FILE}" ]]; then
        rm -f "${LOCK_FILE}" 2>/dev/null || true
    fi
    
    log_debug "Lock released"
}

# =============================================================================
# Directory and Path Functions
# =============================================================================

ensure_directories() {
    log_info "Creating required directories..."
    
    local dirs=(
        "$(dirname "${LOG_FILE}")"
        "$(dirname "${DB_PATH}")"
        "${BACKUP_DIR}"
        "${ROLLBACK_DIR}"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            mkdir -p "${dir}" 2>/dev/null || {
                log_warning "Cannot create directory: ${dir}"
            }
        fi
    done
}

# =============================================================================
# Database Functions
# =============================================================================

init_database() {
    log_info "Initializing database: ${DB_PATH}..."
    
    local db_dir
    db_dir=$(dirname "${DB_PATH}")
    
    if [[ ! -d "${db_dir}" ]]; then
        mkdir -p "${db_dir}" 2>/dev/null || {
            log_error "Cannot create database directory: ${db_dir}"
            exit ${E_ERROR}
        }
    fi
    
    sqlite3 "${DB_PATH}" "
        CREATE TABLE IF NOT EXISTS update_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_time DATETIME NOT NULL,
            end_time DATETIME,
            action TEXT NOT NULL,
            packages_before TEXT,
            packages_after TEXT,
            status TEXT NOT NULL,
            exit_code INTEGER,
            error_message TEXT,
            duration_seconds INTEGER,
            log_file TEXT
        );
        
        CREATE TABLE IF NOT EXISTS package_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            update_id INTEGER NOT NULL,
            package_name TEXT NOT NULL,
            old_version TEXT,
            new_version TEXT,
            FOREIGN KEY (update_id) REFERENCES update_history(id)
        );
        
        CREATE TABLE IF NOT EXISTS rollback_commands (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            update_id INTEGER NOT NULL,
            package_name TEXT NOT NULL,
            command TEXT NOT NULL,
            executed INTEGER DEFAULT 0,
            executed_at DATETIME,
            FOREIGN KEY (update_id) REFERENCES update_history(id)
        );
        
        CREATE INDEX IF NOT EXISTS idx_update_history_status ON update_history(status);
        CREATE INDEX IF NOT EXISTS idx_update_history_start_time ON update_history(start_time);
    " 2>/dev/null || {
        log_error "Failed to initialize database"
        exit ${E_ERROR}
    }
    
    log_debug "Database initialized"
}

# =============================================================================
# Package Management Functions
# =============================================================================

get_installed_packages() {
    log_debug "Getting installed package list..."
    
    dpkg-query -W -f='${Package}\t${Version}\n' 2>/dev/null | sort -u
}

get_upgradable_packages() {
    log_debug "Getting upgradable package list..."
    
    apt list --upgradable 2>/dev/null | grep -v "^Listing" | awk -F' ' '{print $1" "$2" "$3}' | head -n -1
}

get_package_version() {
    local package="$1"
    
    dpkg-query -W -f='${Version}' "${package}" 2>/dev/null || echo "unknown"
}

get_security_updates() {
    log_debug "Checking for security updates..."
    
    apt list --upgradable 2>/dev/null | grep -i security || true
}

# =============================================================================
# Backup Functions
# =============================================================================

backup_package_list() {
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${BACKUP_DIR}/packages_${timestamp}.txt"
    local backup_md5="${backup_file}.md5"
    
    log_info "Backing up package list to: ${backup_file}"
    
    dpkg --get-selections > "${backup_file}" 2>/dev/null || {
        log_error "Failed to backup package list"
        return 1
    }
    
    dpkg-query -W -f='${Package}\t${Version}\n' > "${backup_file}.versions" 2>/dev/null || {
        log_warning "Failed to backup package versions"
    }
    
    md5sum "${backup_file}" > "${backup_md5}" 2>/dev/null || true
    
    log_info "Package list backed up successfully"
    echo "${backup_file}"
}

record_package_snapshot() {
    local update_id="$1"
    
    log_info "Recording package snapshot (update_id: ${update_id})..."
    
    local packages
    packages=$(dpkg-query -W -f='${Package}\t${Version}\n' 2>/dev/null)
    
    local count=0
    while IFS=$'\t' read -r package version; do
        [[ -z "${package}" || -z "${version}" ]] && continue
        
        sqlite3 "${DB_PATH}" "
            INSERT INTO package_snapshots (update_id, package_name, old_version)
            VALUES (${update_id}, '${package}', '${version}');
        " 2>/dev/null || true
        
        ((count++)) || true
    done <<< "${packages}"
    
    log_info "Recorded ${count} packages in snapshot"
}

# =============================================================================
# Update Functions
# =============================================================================

update_package_lists() {
    log_info "Updating package lists..."
    
    local retry=0
    local success=false
    
    while [[ ${retry} -lt ${MAX_RETRIES} ]]; do
        if timeout "${TIMEOUT}" apt-get update &>/dev/null; then
            success=true
            break
        fi
        
        ((retry++))
        log_warning "Package list update failed, retry ${retry}/${MAX_RETRIES}"
        sleep 5
    done
    
    if [[ "${success}" == "false" ]]; then
        log_error "Failed to update package lists after ${MAX_RETRIES} attempts"
        return 1
    fi
    
    log_info "Package lists updated successfully"
    return 0
}

install_updates() {
    log_info "Installing updates..."
    
    local retry=0
    local success=false
    local apt_opts="-y"
    
    if [[ "${DIST_UPGRADE}" == "true" ]]; then
        apt_opts="${apt_opts} --with-new-pkgs"
        log_info "Using dist-upgrade mode"
    fi
    
    DEBIAN_FRONTEND=noninteractive apt-get ${apt_opts} upgrade
    
    if [[ $? -ne 0 ]]; then
        log_error "Package upgrade failed"
        return 1
    fi
    
    if [[ "${DIST_UPGRADE}" == "true" ]]; then
        DEBIAN_FRONTEND=noninteractive apt-get ${apt_opts} dist-upgrade 2>/dev/null || {
            log_warning "dist-upgrade encountered issues"
        }
    fi
    
    log_info "Updates installed successfully"
}

autoremove_packages() {
    if [[ "${AUTO_REMOVE}" == "true" ]]; then
        log_info "Removing unused packages..."
        
        DEBIAN_FRONTEND=noninteractive apt-get -y autoremove 2>/dev/null || {
            log_warning "autoremove encountered issues"
        }
    fi
}

clean_cache() {
    if [[ "${CLEAN_CACHE}" == "true" ]]; then
        log_info "Cleaning package cache..."
        
        apt-get autoclean 2>/dev/null || true
        apt-get clean 2>/dev/null || true
    fi
}

# =============================================================================
# Rollback Functions
# =============================================================================

generate_rollback_commands() {
    local update_id="$1"
    local rollback_file="${ROLLBACK_DIR}/rollback_$(date '+%Y%m%d_%H%M%S').sh"
    
    log_info "Generating rollback commands..."
    
    cat > "${rollback_file}" << 'ROLLBACK_HEADER'
#!/bin/bash
# Rollback script generated by System Update Manager
# Execute with: sudo bash <this_file>
# Warning: This will downgrade packages to previous versions

set -e

echo "Starting rollback process..."
ROLLBACK_HEADER

    local count=0
    
    sqlite3 "${DB_PATH}" "
        SELECT package_name, old_version
        FROM package_snapshots
        WHERE update_id = ${update_id}
        ORDER BY package_name;
    " 2>/dev/null | while read -r line; do
        local package version
        package=$(echo "${line}" | cut -d'|' -f1 | tr -d '|')
        version=$(echo "${line}" | cut -d'|' -f2 | tr -d '|')
        
        [[ -z "${package}" || -z "${version}" ]] && continue
        
        local cmd="apt-get install -y --allow-downgrades ${package}=${version}"
        
        echo "echo \"Downgrading ${package} to ${version}...\"" >> "${rollback_file}"
        echo "${cmd}" >> "${rollback_file}"
        echo "" >> "${rollback_file}"
        
        ((count++)) || true
        
        # Store in database
        sqlite3 "${DB_PATH}" "
            INSERT INTO rollback_commands (update_id, package_name, command)
            VALUES (${update_id}, '${package}', '${cmd}');
        " 2>/dev/null || true
    done
    
    cat >> "${rollback_file}" << 'ROLLBACK_FOOTER'

echo "Rollback complete. Please restart services as needed."
ROLLBACK_FOOTER

    chmod +x "${rollback_file}"
    
    log_info "Rollback script generated: ${rollback_file}"
    log_info "Execute with: sudo ${rollback_file}"
    
    echo "${rollback_file}"
}

# =============================================================================
# History Functions
# =============================================================================

log_update_start() {
    local action="$1"
    
    local start_time
    start_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    sqlite3 "${DB_PATH}" "
        INSERT INTO update_history (start_time, action, status)
        VALUES ('${start_time}', '${action}', 'PENDING');
        SELECT last_insert_rowid();
    " 2>/dev/null
}

log_update_end() {
    local update_id="$1"
    local status="$2"
    local exit_code="$3"
    local error_msg="$4"
    
    local end_time
    end_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    local start_time
    start_time=$(sqlite3 "${DB_PATH}" "SELECT start_time FROM update_history WHERE id = ${update_id};" 2>/dev/null)
    
    local duration_seconds=0
    if [[ -n "${start_time}" ]]; then
        local start_epoch end_epoch
        start_epoch=$(date -d "${start_time}" +%s 2>/dev/null || date -j -f '%Y-%m-%d %H:%M:%S' "${start_time}" +%s 2>/dev/null || echo "0")
        end_epoch=$(date +%s)
        duration_seconds=$((end_epoch - start_epoch))
    fi
    
    sqlite3 "${DB_PATH}" "
        UPDATE update_history
        SET end_time = '${end_time}',
            status = '${status}',
            exit_code = ${exit_code},
            error_message = '${error_msg}',
            duration_seconds = ${duration_seconds}
        WHERE id = ${update_id};
    " 2>/dev/null || true
}

get_last_status() {
    sqlite3 "${DB_PATH}" "
        SELECT status, start_time, end_time, exit_code, error_message
        FROM update_history
        ORDER BY id DESC
        LIMIT 1;
    " 2>/dev/null
}

show_history() {
    local count="${1:-10}"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    UPDATE HISTORY (Last ${count} entries)                    ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    
    sqlite3 "${DB_PATH}" -separator ' | ' "
        SELECT 
            printf('%-5s', id) as id,
            printf('%-19s', start_time) as start,
            printf('%-10s', status) as status,
            printf('%-6s', COALESCE(exit_code, 0)) as exit_code,
            printf('%-5s', COALESCE(duration_seconds, 0) || 's') as duration
        FROM update_history
        ORDER BY id DESC
        LIMIT ${count};
    " 2>/dev/null | while read -r line; do
        echo "║ ${line} ║"
    done
    
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
}

# =============================================================================
# Status Display Functions
# =============================================================================

show_status() {
    local status_info
    status_info=$(get_last_status)
    
    if [[ -z "${status_info}" ]]; then
        echo "No update history found"
        return 0
    fi
    
    local status start_time end_time exit_code error_msg
    status=$(echo "${status_info}" | cut -d'|' -f1)
    start_time=$(echo "${status_info}" | cut -d'|' -f2)
    end_time=$(echo "${status_info}" | cut -d'|' -f3)
    exit_code=$(echo "${status_info}" | cut -d'|' -f4)
    error_msg=$(echo "${status_info}" | cut -d'|' -f5)
    
    local color status_text
    
    case "${status}" in
        SUCCESS)
            color="${GREEN}"
            status_text="Status: ${status}"
            ;;
        FAILED)
            color="${RED}"
            status_text="Status: ${status}"
            ;;
        PENDING)
            color="${YELLOW}"
            status_text="Status: ${status} (running?)"
            ;;
        *)
            color="${BLUE}"
            status_text="Status: ${status}"
            ;;
    esac
    
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║          SYSTEM UPDATE MANAGER - STATUS              ║"
    echo "╠══════════════════════════════════════════════════════╣"
    printf "║ ${color}%-53s${NC} ║\n" "${status_text}"
    echo "║ Start Time:  ${start_time:-N/A}"
    echo "║ End Time:    ${end_time:-N/A}"
    echo "║ Exit Code:   ${exit_code:-N/A}"
    if [[ -n "${error_msg}" && "${error_msg}" != "NULL" ]]; then
        echo "║ Error:       ${error_msg}"
    fi
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
}

show_available_updates() {
    log_info "Checking for available updates..."
    
    local upgradable
    upgradable=$(get_upgradable_packages)
    
    if [[ -z "${upgradable}" ]]; then
        echo ""
        echo -e "${GREEN}✓${NC} System is up to date"
        echo ""
        return 0
    fi
    
    local count
    count=$(echo "${upgradable}" | wc -l)
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║              AVAILABLE UPDATES (${count} packages)                        ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    
    echo "${upgradable}" | while read -r line; do
        [[ -z "${line}" ]] && continue
        printf "║ %-64s ║\n" "${line}"
    done
    
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Check for security updates
    local security
    security=$(get_security_updates)
    
    if [[ -n "${security}" ]]; then
        echo -e "${YELLOW}⚠${NC} Security updates available!"
        echo ""
    fi
}

# =============================================================================
# Cleanup Functions
# =============================================================================

cleanup() {
    local exit_code=$?
    
    log_debug "Cleaning up (exit code: ${exit_code})..."
    
    release_lock
    
    if [[ -n "${TEMP_DIR}" && -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
    fi
    
    log_debug "Cleanup complete"
}

# =============================================================================
# Signal Handlers
# =============================================================================

trap 'cleanup' EXIT
trap 'log_warning "Received SIGINT"; exit 130' INT
trap 'log_warning "Received SIGTERM"; exit 143' TERM

# =============================================================================
# Main Operations
# =============================================================================

do_check() {
    log_info "Running update check..."
    
    update_package_lists || {
        log_error "Failed to update package lists"
        return ${E_NETWORK}
    }
    
    show_available_updates
    
    local update_id
    update_id=$(log_update_start "CHECK")
    
    log_update_end "${update_id}" "SUCCESS" 0 ""
    
    return ${E_SUCCESS}
}

do_install() {
    local backup_file=""
    local update_id=""
    
    log_info "Running update installation..."
    
    # Pre-flight checks
    check_root_privileges
    ensure_directories
    
    # Start database record
    update_id=$(log_update_start "INSTALL")
    
    # Backup current state
    backup_file=$(backup_package_list) || {
        log_error "Backup failed, aborting update"
        log_update_end "${update_id}" "FAILED" ${E_ERROR} "Backup failed"
        return ${E_ERROR}
    }
    
    # Record pre-update snapshot
    record_package_snapshot "${update_id}"
    
    # Update package lists
    update_package_lists || {
        log_error "Failed to update package lists"
        log_update_end "${update_id}" "FAILED" ${E_NETWORK} "Package list update failed"
        return ${E_NETWORK}
    }
    
    # Install updates
    install_updates || {
        log_error "Package installation failed"
        log_update_end "${update_id}" "FAILED" ${E_UPDATE} "Package installation failed"
        
        # Generate rollback commands
        generate_rollback_commands "${update_id}"
        
        return ${E_UPDATE}
    }
    
    # Post-update cleanup
    autoremove_packages
    clean_cache
    
    # Record success
    log_update_end "${update_id}" "SUCCESS" 0 ""
    
    log_info "Update completed successfully"
    
    return ${E_SUCCESS}
}

do_cron() {
    local backup_file=""
    local update_id=""
    
    log_info "Running cron update..."
    log_to_syslog "info" "Starting scheduled update"
    
    # Pre-flight checks
    check_root_privileges
    ensure_directories
    
    # Start database record
    update_id=$(log_update_start "CRON")
    
    # Backup current state
    backup_file=$(backup_package_list) || {
        log_error "Backup failed, aborting update"
        log_update_end "${update_id}" "FAILED" ${E_ERROR} "Backup failed"
        log_to_syslog "error" "Update failed: backup failed"
        return ${E_ERROR}
    }
    
    # Record pre-update snapshot
    record_package_snapshot "${update_id}"
    
    # Update package lists
    update_package_lists || {
        log_error "Failed to update package lists"
        log_update_end "${update_id}" "FAILED" ${E_NETWORK} "Package list update failed"
        log_to_syslog "error" "Update failed: network error"
        return ${E_NETWORK}
    }
    
    # Check if updates available
    local upgradable
    upgradable=$(get_upgradable_packages)
    
    if [[ -z "${upgradable}" ]]; then
        log_info "No updates available"
        log_update_end "${update_id}" "SUCCESS" 0 ""
        log_to_syslog "info" "No updates available"
        return ${E_SUCCESS}
    fi
    
    # Install updates
    install_updates || {
        log_error "Package installation failed"
        log_update_end "${update_id}" "FAILED" ${E_UPDATE} "Package installation failed"
        log_to_syslog "error" "Update failed: installation failed"
        
        # Generate rollback commands
        generate_rollback_commands "${update_id}"
        
        return ${E_UPDATE}
    }
    
    # Post-update cleanup
    autoremove_packages
    clean_cache
    
    # Record success
    log_update_end "${update_id}" "SUCCESS" 0 ""
    log_to_syslog "info" "Update completed successfully"
    
    log_info "Cron update completed successfully"
    
    return ${E_SUCCESS}
}

do_rollback() {
    log_info "Preparing rollback..."
    
    local last_update_id
    last_update_id=$(sqlite3 "${DB_PATH}" "SELECT id FROM update_history WHERE status = 'FAILED' ORDER BY id DESC LIMIT 1;" 2>/dev/null)
    
    if [[ -z "${last_update_id}" ]]; then
        log_error "No failed updates found to roll back"
        return ${E_ERROR}
    fi
    
    local rollback_file
    rollback_file="${ROLLBACK_DIR}/rollback_update_${last_update_id}.sh"
    
    sqlite3 "${DB_PATH}" "
        SELECT command FROM rollback_commands WHERE update_id = ${last_update_id} AND executed = 0;
    " 2>/dev/null | head -5
    
    echo ""
    log_info "To execute rollback, run:"
    log_info "  sudo ${rollback_file}"
    echo ""
}

# =============================================================================
# Help and Usage Functions
# =============================================================================

show_help() {
    cat << EOF
System Update Manager v${SCRIPT_VERSION}
Automated system update management for Debian/Ubuntu

Usage: ${SCRIPT_NAME} [OPTIONS]

Options:
    --check              Check for available updates (no installation)
    --install            Install available updates (requires sudo)
    --backup             Backup current package list only
    --rollback           Show rollback commands for last failed update
    --history [N]        Show last N update records (default: 10)
    --status             Show last run status
    --cron               Cron mode: auto-check + auto-install
    --dry-run            Show what would be done (simulate)
    --config FILE        Use alternate configuration file
    --help               Show this help message
    --version            Show version information

Examples:
    # Check for updates (no root required)
    ${SCRIPT_NAME} --check

    # Install updates (requires root)
    sudo ${SCRIPT_NAME} --install

    # Show history
    ${SCRIPT_NAME} --history 20

    # Show last status
    ${SCRIPT_NAME} --status

    # Run as cron job
    sudo ${SCRIPT_NAME} --cron

Exit Codes:
    0  Success
    1  General error
    2  Permission denied (need sudo)
    3  Lock file exists (concurrent run)
    4  Update failed
    5  Rollback failed
    6  Configuration error
    7  Network/repository error
    8  Disk space insufficient

Configuration:
    Edit ${CONFIG_FILE} to customize behavior.

Files:
    Config:     ${CONFIG_FILE}
    Log:        ${LOG_FILE}
    Database:   ${DB_PATH}
    Backups:    ${BACKUP_DIR}
    Rollback:   ${ROLLBACK_DIR}

For more information, see README.md
EOF
}

show_version() {
    echo "${SCRIPT_NAME} version ${SCRIPT_VERSION}"
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    local mode=""
    local dry_run=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check)
                mode="check"
                shift
                ;;
            --install)
                mode="install"
                shift
                ;;
            --backup)
                mode="backup"
                shift
                ;;
            --rollback)
                mode="rollback"
                shift
                ;;
            --history)
                mode="history"
                if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
                    HISTORY_COUNT="$2"
                    shift
                fi
                shift
                ;;
            --status)
                mode="status"
                shift
                ;;
            --cron)
                mode="cron"
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --config)
                if [[ -n "${2:-}" ]]; then
                    CONFIG_FILE="$2"
                    shift 2
                else
                    log_error "--config requires a file path"
                    exit ${E_ERROR}
                fi
                ;;
            --help|-h)
                show_help
                exit ${E_SUCCESS}
                ;;
            --version|-v)
                show_version
                exit ${E_SUCCESS}
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit ${E_ERROR}
                ;;
        esac
    done
    
    # Validate Bash version
    validate_bash_version
    
    # Check OS compatibility
    check_os_compatibility
    
    # Load configuration
    load_config
    
    # Initialize database
    init_database
    
    # Acquire lock for operations that need it
    if [[ "${mode}" != "check" && "${mode}" != "status" && "${mode}" != "history" ]]; then
        acquire_lock
    fi
    
    # Dry run mode
    if [[ "${dry_run}" == "true" ]]; then
        log_info "DRY RUN MODE - No changes will be made"
    fi
    
    # Execute requested mode
    local exit_code=${E_SUCCESS}
    
    case "${mode}" in
        check)
            do_check || exit_code=$?
            ;;
        install)
            if [[ "${dry_run}" == "true" ]]; then
                log_info "Would install updates"
                get_upgradable_packages
            else
                do_install || exit_code=$?
            fi
            ;;
        backup)
            check_root_privileges
            backup_package_list
            ;;
        rollback)
            do_rollback || exit_code=$?
            ;;
        history)
            show_history "${HISTORY_COUNT:-10}"
            ;;
        status)
            show_status
            ;;
        cron)
            if [[ "${dry_run}" == "true" ]]; then
                log_info "Would run in cron mode"
            else
                do_cron || exit_code=$?
            fi
            ;;
        "")
            log_error "No mode specified"
            show_help
            exit_code=${E_ERROR}
            ;;
        *)
            log_error "Unknown mode: ${mode}"
            exit_code=${E_ERROR}
            ;;
    esac
    
    exit ${exit_code}
}

# Run main function
main "$@"