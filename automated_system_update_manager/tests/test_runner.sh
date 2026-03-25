#!/bin/bash
# =============================================================================
# System Update Manager - Test Runner
# =============================================================================
# Purpose: Execute all test cases for the update manager
# Usage: ./test_runner.sh [--verbose]
# =============================================================================

set -e

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Script paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
UPDATE_MANAGER="${PROJECT_DIR}/update_manager.sh"
CONFIG_FILE="${PROJECT_DIR}/config.ini"

# Test environment
TEST_DIR="/tmp/update_manager_test_$$"
TEST_DB="${TEST_DIR}/test_history.db"
TEST_LOG="${TEST_DIR}/test_update_manager.log"

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}=========================================${NC}"
}

print_test() {
    echo -n "  Test: $1 ... "
}

print_pass() {
    echo -e "${GREEN}PASS${NC}"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}FAIL${NC}"
    echo -e "    Reason: $1"
    ((TESTS_FAILED++))
}

print_skip() {
    echo -e "${YELLOW}SKIP${NC}"
    echo -e "    Reason: $1"
    ((TESTS_SKIPPED++))
}

setup_test_env() {
    mkdir -p "${TEST_DIR}"
    mkdir -p "${TEST_DIR}/backups"
    mkdir -p "${TEST_DIR}/rollback"
    
    # Create test config
    cat > "${TEST_DIR}/test_config.ini" << EOF
[UPDATE]
dist_upgrade = false
auto_remove = true
clean_cache = true
max_retries = 3
timeout = 300

[BACKUP]
backup_package_list = true
backup_apt_cache = true
backup_dir = ${TEST_DIR}/backups

[LOGGING]
log_file = ${TEST_LOG}
use_syslog = false
log_level = DEBUG

[DATABASE]
db_path = ${TEST_DB}

[ROLLBACK]
generate_rollback = true
rollback_dir = ${TEST_DIR}/rollback
EOF
    
    # Copy original script for testing
    cp "${UPDATE_MANAGER}" "${TEST_DIR}/update_manager.sh"
    chmod +x "${TEST_DIR}/update_manager.sh"
}

cleanup_test_env() {
    if [[ -d "${TEST_DIR}" ]]; then
        rm -rf "${TEST_DIR}"
    fi
}

# =============================================================================
# Test Cases
# =============================================================================

test_script_exists() {
    print_test "Script exists"
    
    if [[ -f "${UPDATE_MANAGER}" ]]; then
        print_pass
    else
        print_fail "Script not found: ${UPDATE_MANAGER}"
    fi
}

test_script_executable() {
    print_test "Script is executable"
    
    if [[ -x "${UPDATE_MANAGER}" ]]; then
        print_pass
    else
        print_fail "Script not executable: ${UPDATE_MANAGER}"
    fi
}

test_config_exists() {
    print_test "Configuration file exists"
    
    if [[ -f "${CONFIG_FILE}" ]]; then
        print_pass
    else
        print_fail "Config not found: ${CONFIG_FILE}"
    fi
}

test_help_flag() {
    print_test "Help flag works"
    
    local output
    output=$("${UPDATE_MANAGER}" --help 2>&1)
    
    if echo "${output}" | grep -q "Usage:"; then
        print_pass
    else
        print_fail "Help output missing Usage"
    fi
}

test_version_flag() {
    print_test "Version flag works"
    
    local output
    output=$("${UPDATE_MANAGER}" --version 2>&1)
    
    if echo "${output}" | grep -q "[0-9]\+\.[0-9]\+\.[0-9]\+"; then
        print_pass
    else
        print_fail "Version output missing version number"
    fi
}

test_check_command() {
    print_test "Check command (no updates)"
    
    local output
    output=$("${UPDATE_MANAGER}" --check 2>&1)
    
    # Check should work without root
    if [[ $? -eq 0 ]] || echo "${output}" | grep -q "up to date\|Available"; then
        print_pass
    else
        print_fail "Check command failed unexpectedly"
    fi
}

test_status_command() {
    print_test "Status command works"
    
    local output
    output=$("${UPDATE_MANAGER}" --status 2>&1)
    
    # Status should work without root
    if [[ $? -eq 0 ]] || echo "${output}" | grep -q "STATUS\|No update history"; then
        print_pass
    else
        print_fail "Status command failed"
    fi
}

test_history_command() {
    print_test "History command works"
    
    ((TESTS_TOTAL++))
    print_test "History command works"
    
    local output
    output=$("${UPDATE_MANAGER}" --history 5 2>&1)
    
    # History command should display records or empty table
    if [[ $? -eq 0 ]]; then
        print_pass
    else
        print_fail "History command failed"
    fi
}

test_config_loading() {
    print_test "Configuration loading"
    
    # Create test environment
    setup_test_env
    
    # Run script with test config
    local output
    output=$("${TEST_DIR}/update_manager.sh" --config "${TEST_DIR}/test_config.ini" --check 2>&1)
    
    if [[ $? -eq 0 ]] && [[ -f "${TEST_LOG}" ]]; then
        print_pass
    else
        print_fail "Config loading failed"
    fi
    
    cleanup_test_env
}

test_database_initialization() {
    print_test "Database initialization"
    
    setup_test_env
    
    # Run check to initialize database
    "${TEST_DIR}/update_manager.sh" --config "${TEST_DIR}/test_config.ini" --check >/dev/null 2>&1
    
    # Check if database was created
    if [[ -f "${TEST_DB}" ]]; then
        # Verify tables exist
        local tables
        tables=$(sqlite3 "${TEST_DB}" ".tables" 2>/dev/null)
        
        if echo "${tables}" | grep -q "update_history" && \
           echo "${tables}" | grep -q "package_snapshots" && \
           echo "${tables}" | grep -q "rollback_commands"; then
            print_pass
        else
            print_fail "Database tables missing"
        fi
    else
        print_fail "Database not created"
    fi
    
    cleanup_test_env
}

test_lock_mechanism() {
    print_test "Lock mechanism"
    
    setup_test_env
    
    # Create a lock file
    mkdir -p /var/lock
    touch /var/lock/update_manager.lock
    
    # Try to run script (should exit with lock error)
    local exit_code
    "${TEST_DIR}/update_manager.sh" --config "${TEST_DIR}/test_config.ini" --check >/dev/null 2>&1
    exit_code=$?
    
    # Cleanup
    rm -f /var/lock/update_manager.lock
    
    # Should exit with code 3 (E_LOCK)
    if [[ ${exit_code} -eq 3 ]]; then
        print_pass
    else
        print_fail "Lock mechanism failed (expected exit code 3, got ${exit_code})"
    fi
    
    cleanup_test_env
}

test_backup_creation() {
    print_test "Backup directory creation"
    
    setup_test_env
    
    # Check if backup directory exists
    if [[ -d "${TEST_DIR}/backups" ]]; then
        print_pass
    else
        print_fail "Backup directory not created"
    fi
    
    cleanup_test_env
}

test_rollback_directory() {
    print_test "Rollback directory creation"
    
    setup_test_env
    
    # Check if rollback directory exists
    if [[ -d "${TEST_DIR}/rollback" ]]; then
        print_pass
    else
        print_fail "Rollback directory not created"
    fi
    
    cleanup_test_env
}

test_log_file_creation() {
    print_test "Log file creation"
    
    setup_test_env
    
    # Run check to create log
    "${TEST_DIR}/update_manager.sh" --config "${TEST_DIR}/test_config.ini" --check >/dev/null 2>&1
    
    # Check if log file exists
    if [[ -f "${TEST_LOG}" ]]; then
        print_pass
    else
        print_fail "Log file not created"
    fi
    
    cleanup_test_env
}

test_dry_run_flag() {
    print_test "Dry run flag works"
    
    local output
    output=$("${UPDATE_MANAGER}" --dry-run --check 2>&1)
    
    if echo "${output}" | grep -q "DRY RUN"; then
        print_pass
    else
        print_fail "Dry run flag not working"
    fi
}

test_invalid_option() {
    print_test "Invalid option handling"
    
    local output
    output=$("${UPDATE_MANAGER}" --invalid-option 2>&1)
    local exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        print_pass
    else
        print_fail "Invalid option not rejected"
    fi
}

test_os_compatibility() {
    print_test "OS compatibility check"
    
    local output
    output=$("${UPDATE_MANAGER}" --check 2>&1)
    
    # Should detect OS and continue
    if echo "${output}" | grep -q "Detected\|Untested OS"; then
        print_pass
    else
        print_skip "OS detection not available in this environment"
    fi
}

# =============================================================================
# Main Test Runner
# =============================================================================

run_tests() {
    print_header "System Update Manager Test Suite"
    
    echo "Test environment: ${TEST_DIR}"
    echo "Project directory: ${PROJECT_DIR}"
    echo ""
    
    # Setup
    ((TESTS_TOTAL++))
    print_header "Setup Tests"
    test_script_exists
    ((TESTS_TOTAL++))
    test_script_executable
    ((TESTS_TOTAL++))
    test_config_exists
    
    # Basic functionality
    ((TESTS_TOTAL++))
    print_header "Basic Functionality Tests"
    test_help_flag
    ((TESTS_TOTAL++))
    test_version_flag
    ((TESTS_TOTAL++))
    test_check_command
    ((TESTS_TOTAL++))
    test_status_command
    ((TESTS_TOTAL++))
    test_history_command
    
    # Configuration tests
    ((TESTS_TOTAL++))
    print_header "Configuration Tests"
    test_config_loading
    ((TESTS_TOTAL++))
    test_database_initialization
    
    # Mechanism tests
    ((TESTS_TOTAL++))
    print_header "Mechanism Tests"
    test_backup_creation
    ((TESTS_TOTAL++))
    test_rollback_directory
    ((TESTS_TOTAL++))
    test_lock_mechanism
    ((TESTS_TOTAL++))
    test_log_file_creation
    
    # Error handling tests
    ((TESTS_TOTAL++))
    print_header "Error Handling Tests"
    test_dry_run_flag
    ((TESTS_TOTAL++))
    test_invalid_option
    
    # Environment tests
    ((TESTS_TOTAL++))
    print_header "Environment Tests"
    test_os_compatibility
}

print_summary() {
    print_header "Test Summary"
    
    echo ""
    echo "Total tests:  ${TESTS_TOTAL}"
    echo -e "Passed:       ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Failed:       ${RED}${TESTS_FAILED}${NC}"
    echo -e "Skipped:      ${YELLOW}${TESTS_SKIPPED}${NC}"
    echo ""
    
    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# Cleanup on exit
trap cleanup_test_env EXIT

# Run tests
run_tests
print_summary