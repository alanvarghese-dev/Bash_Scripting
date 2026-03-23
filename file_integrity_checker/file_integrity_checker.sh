#!/bin/bash
# =============================================================================
# File Integrity Checker
# =============================================================================
# Purpose: Monitor critical configuration files and system files for changes
#          by calculating and comparing SHA-256 hashes stored in SQLite database
# Author: DevOps Team
# Usage: ./file_integrity_checker.sh [--init|--check|--help]
# =============================================================================

# =============================================================================
# Global Variables and Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
CONFIG_FILE="${SCRIPT_DIR}/config.ini"
ERROR_LOG="${SCRIPT_DIR}/error_log.txt"
DATABASE_PATH=""
EMAIL_SENDER=""
EMAIL_RECIPIENT=""
SMTP_SERVER=""
SMTP_PORT=""
SMTP_USERNAME=""
SMTP_PASSWORD=""
FILES_TO_MONITOR=()

# =============================================================================
# Error Handling Functions
# =============================================================================

# Log error messages to error_log.txt
log_error() {
    local error_message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${error_message}" >> "${ERROR_LOG}"
}

# Log informational messages
log_info() {
    local info_message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] INFO: ${info_message}"
}

# =============================================================================
# Configuration Loading Functions
# =============================================================================

# Parse INI-style configuration file
load_config() {
    log_info "Loading configuration from ${CONFIG_FILE}..."

    # Check if config file exists
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log_error "Configuration file not found: ${CONFIG_FILE}"
        echo "Error: Configuration file not found: ${CONFIG_FILE}"
        exit 1
    fi

    # Parse [DATABASE] section
    DATABASE_PATH=$(grep "^db_path" "${CONFIG_FILE}" | cut -d'=' -f2 | tr -d ' ')
    if [[ -z "${DATABASE_PATH}" ]]; then
        log_error "db_path not found in configuration"
        exit 1
    fi
    
    # Make database path absolute if relative
    if [[ ! "${DATABASE_PATH}" = /* ]]; then
        DATABASE_PATH="${SCRIPT_DIR}/${DATABASE_PATH}"
    fi

    # Parse [EMAIL] section
    EMAIL_SENDER=$(grep "^sender_address" "${CONFIG_FILE}" | cut -d'=' -f2 | tr -d ' ')
    EMAIL_RECIPIENT=$(grep "^recipient_address" "${CONFIG_FILE}" | cut -d'=' -f2 | tr -d ' ')
    SMTP_SERVER=$(grep "^smtp_server" "${CONFIG_FILE}" | cut -d'=' -f2 | tr -d ' ')
    SMTP_PORT=$(grep "^smtp_port" "${CONFIG_FILE}" | cut -d'=' -f2 | tr -d ' ')
    SMTP_USERNAME=$(grep "^smtp_username" "${CONFIG_FILE}" | cut -d'=' -f2 | tr -d ' ')
    SMTP_PASSWORD=$(grep "^smtp_password" "${CONFIG_FILE}" | cut -d'=' -f2 | tr -d ' ')

    # Validate email configuration
    if [[ -z "${EMAIL_SENDER}" || -z "${EMAIL_RECIPIENT}" ]]; then
        log_error "Email configuration incomplete"
        exit 1
    fi

    # Parse [FILES] section - collect all file patterns
    local in_files_section=false
    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "${line}" ]] && continue
        
        # Check for section headers first
        if [[ "${line}" =~ ^\[FILES\] ]]; then
            in_files_section=true
            continue
        fi
        
        # Exit FILES section if we hit another section
        if [[ "${in_files_section}" == true && "${line}" =~ ^\[.*\]$ ]]; then
            in_files_section=false
            continue
        fi
        
        # Skip comments
        [[ "${line}" =~ ^#.*$ ]] && continue
        
        # Add file pattern if in FILES section
        if [[ "${in_files_section}" == true ]]; then
            FILES_TO_MONITOR+=("${line}")
        fi
    done < "${CONFIG_FILE}"

    log_info "Configuration loaded successfully"
    log_info "Database: ${DATABASE_PATH}"
    log_info "Monitoring ${#FILES_TO_MONITOR[@]} file patterns"
}

# =============================================================================
# Database Functions
# =============================================================================

# Initialize SQLite database and create table if not exists
init_database() {
    log_info "Initializing database: ${DATABASE_PATH}..."
    
    # Create database directory if it doesn't exist
    local db_dir
    db_dir=$(dirname "${DATABASE_PATH}")
    if [[ ! -d "${db_dir}" ]]; then
        mkdir -p "${db_dir}"
    fi
    
    # Create table if not exists
    sqlite3 "${DATABASE_PATH}" "
        CREATE TABLE IF NOT EXISTS hashes (
            hashes INTEGER PRIMARY KEY AUTOINCREMENT,
            file_path TEXT NOT NULL UNIQUE,
            hash TEXT NOT NULL,
            last_updated DATETIME DEFAULT CURRENT_TIMESTAMP
        );
    "
    
    # Check if table creation was successful
    if [[ $? -ne 0 ]]; then
        log_error "Failed to create database table"
        exit 1
    fi
    
    log_info "Database initialized successfully"
}

# Store file hash in database (insert or update)
store_hash() {
    local file_path="$1"
    local hash_value="$2"
    
    # Use INSERT OR REPLACE to handle both new and existing files
    sqlite3 "${DATABASE_PATH}" "
        INSERT OR REPLACE INTO hashes (file_path, hash, last_updated)
        VALUES ('${file_path}', '${hash_value}', datetime('now'));
    "
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to store hash for file: ${file_path}"
        return 1
    fi
    
    return 0
}

# Retrieve stored hash for a file
get_stored_hash() {
    local file_path="$1"
    
    local stored_hash
    stored_hash=$(sqlite3 "${DATABASE_PATH}" "
        SELECT hash FROM hashes WHERE file_path = '${file_path}';
    " 2>/dev/null)
    
    echo "${stored_hash}"
}

# Check if file exists in database
file_exists_in_db() {
    local file_path="$1"
    
    local count
    count=$(sqlite3 "${DATABASE_PATH}" "
        SELECT COUNT(*) FROM hashes WHERE file_path = '${file_path}';
    " 2>/dev/null)
    
    [[ "${count}" -gt 0 ]]
}

# =============================================================================
# File Discovery Functions
# =============================================================================

# Expand file patterns to actual file paths
get_files_to_monitor() {
    local files=()
    
    for pattern in "${FILES_TO_MONITOR[@]}"; do
        # Skip empty patterns
        [[ -z "${pattern}" ]] && continue
        
        # Handle directory patterns (ending with /)
        if [[ "${pattern}" == */ ]]; then
            # Find all files in directory recursively
            if [[ -d "${pattern}" ]]; then
                while IFS= read -r -d '' file; do
                    files+=("${file}")
                done < <(find "${pattern}" -type f -print0 2>/dev/null)
            else
                log_error "Directory not found: ${pattern}"
            fi
        else
            # Handle glob patterns
            # Get directory part and pattern part
            local dir pattern_part
            dir=$(dirname "${pattern}")
            pattern_part=$(basename "${pattern}")
            
            # If directory doesn't exist, skip
            if [[ ! -d "${dir}" ]]; then
                log_error "Directory not found: ${dir}"
                continue
            fi
            
            # Find matching files
            while IFS= read -r -d '' file; do
                files+=("${file}")
            done < <(find "${dir}" -maxdepth 1 -type f -name "${pattern_part}" -print0 2>/dev/null)
        fi
    done
    
    # Return files as newline-separated list
    printf '%s\n' "${files[@]}"
}

# =============================================================================
# Hashing Functions
# =============================================================================

# Calculate SHA-256 hash of a file
calculate_hash() {
    local file_path="$1"
    
    # Check if file exists and is readable
    if [[ ! -f "${file_path}" ]]; then
        log_error "File not found: ${file_path}"
        return 1
    fi
    
    if [[ ! -r "${file_path}" ]]; then
        log_error "File not readable: ${file_path}"
        return 1
    fi
    
    # Calculate SHA-256 hash (try different commands for compatibility)
    local hash_value=""
    
    # Try sha256sum first (Linux)
    if command -v sha256sum &>/dev/null; then
        hash_value=$(sha256sum "${file_path}" 2>/dev/null | awk '{print $1}')
    # Try shasum (macOS)
    elif command -v shasum &>/dev/null; then
        hash_value=$(shasum -a 256 "${file_path}" 2>/dev/null | awk '{print $1}')
    # Try openssl (fallback)
    elif command -v openssl &>/dev/null; then
        hash_value=$(openssl dgst -sha256 "${file_path}" 2>/dev/null | awk '{print $2}')
    else
        log_error "No SHA-256 hash tool available"
        return 1
    fi
    
    if [[ $? -ne 0 || -z "${hash_value}" ]]; then
        log_error "Failed to calculate hash for: ${file_path}"
        return 1
    fi
    
    echo "${hash_value}"
    return 0
}

# =============================================================================
# Alerting Functions
# =============================================================================

# Send email alert when file integrity is compromised
send_alert() {
    local file_path="$1"
    local old_hash="$2"
    local new_hash="$3"
    
    local subject="File Integrity Alert"
    local body="File integrity violation detected!

File: ${file_path}
Old Hash: ${old_hash}
New Hash: ${new_hash}
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')

This file has been modified. Please investigate immediately."

    log_info "Sending alert for: ${file_path}"
    
    # Send email - try different methods for compatibility
    local mail_sent=false
    
    # Method 1: Use sendmail/ssmtp if available (for MailHog relay)
    if command -v sendmail &>/dev/null; then
        {
            echo "Subject: ${subject}"
            echo "From: ${EMAIL_SENDER}"
            echo "To: ${EMAIL_RECIPIENT}"
            echo ""
            echo "${body}"
        } | sendmail -t 2>> "${ERROR_LOG}" && mail_sent=true
    fi
    
    # Method 2: Use curl for MailHog HTTP API
    if [[ "${mail_sent}" == false ]] && command -v curl &>/dev/null; then
        local smtp_server="${SMTP_SERVER:-mailhog}"
        local smtp_port="${SMTP_PORT:-1025}"
        
        # Try MailHog HTTP API on port 8025
        curl -s --connect-timeout 2 "http://${smtp_server%:*}:8025/api/v2/send" \
            -H "Content-Type: application/json" \
            -d "{\"sender\":\"${EMAIL_SENDER}\",\"recipients\":[\"${EMAIL_RECIPIENT}\"],\"subject\":\"${subject}\",\"text\":\"${body}\"}" \
            > /dev/null 2>> "${ERROR_LOG}" && mail_sent=true
    fi
    
    # Method 3: Simple mail command fallback
    if [[ "${mail_sent}" == false ]]; then
        echo "${body}" | mail -s "${subject}" "${EMAIL_RECIPIENT}" 2>> "${ERROR_LOG}" && mail_sent=true
    fi
    
    if [[ "${mail_sent}" == true ]]; then
        log_info "Alert sent successfully for: ${file_path}"
    else
        log_error "Failed to send alert for: ${file_path}"
    fi
}

# =============================================================================
# Integrity Check Functions
# =============================================================================

# Check integrity of a single file
check_file_integrity() {
    local file_path="$1"
    
    # Calculate current hash
    local current_hash
    current_hash=$(calculate_hash "${file_path}")
    
    if [[ $? -ne 0 || -z "${current_hash}" ]]; then
        return 1
    fi
    
    # Check if file exists in database
    if file_exists_in_db "${file_path}"; then
        # Get stored hash
        local stored_hash
        stored_hash=$(get_stored_hash "${file_path}")
        
        # Compare hashes
        if [[ "${current_hash}" != "${stored_hash}" ]]; then
            log_info "INTEGRITY VIOLATION: ${file_path}"
            log_error "File modified: ${file_path} (old: ${stored_hash}, new: ${current_hash})"
            
            # Send alert
            send_alert "${file_path}" "${stored_hash}" "${current_hash}"
            
            # Update hash in database
            store_hash "${file_path}" "${current_hash}"
            
            return 1
        else
            log_info "OK: ${file_path}"
            return 0
        fi
    else
        # New file - store initial hash
        log_info "NEW FILE: ${file_path} - storing initial hash"
        store_hash "${file_path}" "${current_hash}"
        return 0
    fi
}

# Run integrity check on all monitored files
run_integrity_check() {
    log_info "Starting integrity check..."
    
    # Get list of files to monitor
    local files
    files=$(get_files_to_monitor)
    
    if [[ -z "${files}" ]]; then
        log_error "No files found to monitor"
        echo "No files found matching the specified patterns"
        return 1
    fi
    
    local total_files=0
    local checked_files=0
    local violated_files=0
    local error_files=0
    
    # Count total files
    total_files=$(echo "${files}" | wc -l)
    
    log_info "Found ${total_files} files to monitor"
    
    # Process each file
    while IFS= read -r file_path; do
        [[ -z "${file_path}" ]] && continue
        
        if check_file_integrity "${file_path}"; then
            ((checked_files++))
        else
            ((error_files++))
        fi
    done <<< "${files}"
    
    log_info "Integrity check completed: ${checked_files} OK, ${error_files} issues"
    
    return 0
}

# =============================================================================
# Initialization Functions
# =============================================================================

# Initialize baseline hashes for all files (first run)
initialize_baseline() {
    log_info "Initializing baseline hashes..."
    
    # Get list of files to monitor
    local files
    files=$(get_files_to_monitor)
    
    if [[ -z "${files}" ]]; then
        log_error "No files found to monitor"
        echo "No files found matching the specified patterns"
        return 1
    fi
    
    local total_files=0
    local stored_files=0
    
    # Count total files
    total_files=$(echo "${files}" | wc -l)
    
    log_info "Found ${total_files} files to monitor"
    
    # Store hash for each file
    while IFS= read -r file_path; do
        [[ -z "${file_path}" ]] && continue
        
        local hash_value
        hash_value=$(calculate_hash "${file_path}")
        
        if [[ $? -eq 0 && -n "${hash_value}" ]]; then
            if store_hash "${file_path}" "${hash_value}"; then
                log_info "Stored hash: ${file_path}"
                ((stored_files++))
            else
                log_error "Failed to store hash: ${file_path}"
            fi
        fi
    done <<< "${files}"
    
    log_info "Baseline initialization completed: ${stored_files}/${total_files} files stored"
    echo "Baseline initialized: ${stored_files}/${total_files} files"
    
    return 0
}

# =============================================================================
# Help and Usage Functions
# =============================================================================

# Display usage information
show_help() {
    cat << EOF
File Integrity Checker - Monitor critical files for unauthorized changes

Usage: $0 [OPTIONS]

Options:
    --init           Initialize baseline hashes for all files (first run)
    --check          Run integrity check against stored hashes
    --help           Display this help message

Examples:
    $0 --init        # First run: create baseline hashes
    $0 --check       # Subsequent runs: check for changes

Description:
    This tool monitors specified files and directories for changes by
    calculating SHA-256 hashes and storing them in a SQLite database.
    When a hash mismatch is detected, an email alert is sent.

Configuration:
    Edit config.ini to configure:
    - Database location
    - Email settings (SMTP)
    - Files and directories to monitor

EOF
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    # Parse command line arguments
    local mode="check"
    
    case "${1:-}" in
        --init)
            mode="init"
            ;;
        --check)
            mode="check"
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            mode="check"
            ;;
        *)
            echo "Unknown option: ${1}"
            show_help
            exit 1
            ;;
    esac
    
    # Initialize
    log_info "========================================="
    log_info "File Integrity Checker Starting..."
    log_info "========================================="
    
    # Load configuration
    load_config
    
    # Initialize database
    init_database
    
    # Execute requested mode
    case "${mode}" in
        init)
            initialize_baseline
            ;;
        check)
            run_integrity_check
            ;;
    esac
    
    local exit_code=$?
    
    log_info "File Integrity Checker Finished"
    log_info "========================================="
    
    exit ${exit_code}
}

# Run main function with all arguments
main "$@"
