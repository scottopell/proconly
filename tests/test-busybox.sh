#!/bin/bash
# test-busybox.sh - EARS requirement testing for proconly.sh
# Tests requirements defined in tests/requirements.md

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROCONLY_SCRIPT="$PROJECT_ROOT/proconly.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if proconly.sh exists
if [ ! -f "$PROCONLY_SCRIPT" ]; then
    log_error "proconly.sh not found at $PROCONLY_SCRIPT"
    exit 1
fi

usage() {
    echo "Usage: $0 [MODE] [ARGUMENT]"
    echo ""
    echo "Modes:"
    echo "  run       - Run proconly.sh in busybox (quick manual test)"
    echo "  req       - Test specific EARS requirement (primary mode)"
    echo ""
    echo "Requirements:"
    echo "  REQ-001   - Script execution"
    echo "  REQ-002   - Process discovery"
    echo "  REQ-003   - Process information display"
    echo "  REQ-004   - Command line parsing"
    echo "  REQ-005   - Process state detection"
    echo "  REQ-010   - Open file enumeration"
    echo "  REQ-011   - Socket detection & address resolution"
    echo "  all       - Run all requirement tests"
    echo ""
    echo "Examples:"
    echo "  $0 run              # Quick manual execution"
    echo "  $0 req REQ-001      # Test single requirement"
    echo "  $0 req all          # Test all requirements (primary workflow)"
}

if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

# ============================================================================
# EARS REQUIREMENT TESTS
# See tests/requirements.md for full requirement definitions
# ============================================================================

# REQ-001: Script Execution
test_req_001() {
    log_info "Testing REQ-001: Script Execution"

    local exit_code=0
    local output
    output=$(docker run --rm -i busybox sh -s < "$PROCONLY_SCRIPT" 2>&1) || exit_code=$?

    if [ $exit_code -eq 0 ]; then
        log_success "✓ REQ-001: Script exits with code 0"
    else
        log_error "✗ REQ-001: Script exited with code $exit_code"
        return 1
    fi

    if [ -n "$output" ]; then
        log_success "✓ REQ-001: Script produces output"
    else
        log_error "✗ REQ-001: No output produced"
        return 1
    fi

    return 0
}

# REQ-002: Process Discovery
test_req_002() {
    log_info "Testing REQ-002: Process Discovery"

    local output
    output=$(docker run --rm -i busybox sh -s < "$PROCONLY_SCRIPT" 2>&1)

    if echo "$output" | grep -q "PID 1"; then
        log_success "✓ REQ-002: PID 1 (init) discovered"
    else
        log_error "✗ REQ-002: PID 1 not found"
        return 1
    fi

    local pid_count
    pid_count=$(echo "$output" | grep -c "^PID [0-9]" || true)

    if [ "$pid_count" -gt 0 ]; then
        log_success "✓ REQ-002: Discovered $pid_count processes"
    else
        log_error "✗ REQ-002: No processes discovered"
        return 1
    fi

    return 0
}

# REQ-003: Process Information Display
test_req_003() {
    log_info "Testing REQ-003: Process Information Display"

    local output
    output=$(docker run --rm -i busybox sh -s < "$PROCONLY_SCRIPT" 2>&1)

    if echo "$output" | grep -qE "PID [0-9]+"; then
        log_success "✓ REQ-003: PID displayed"
    else
        log_error "✗ REQ-003: PID not displayed"
        return 1
    fi

    if echo "$output" | grep -qE "\[[A-Z?]\]"; then
        log_success "✓ REQ-003: Process state displayed"
    else
        log_error "✗ REQ-003: Process state not displayed"
        return 1
    fi

    if echo "$output" | grep -qE "PID [0-9]+ \[[A-Z?]\]:"; then
        log_success "✓ REQ-003: Command displayed"
    else
        log_error "✗ REQ-003: Command not displayed"
        return 1
    fi

    return 0
}

# REQ-004: Command Line Parsing
test_req_004() {
    log_info "Testing REQ-004: Command Line Parsing"

    local output
    output=$(cat "$PROCONLY_SCRIPT" | docker run --rm -i busybox sh -c '
# Start background process with known cmdline
sleep 999 &
sleep 0.1

# Read and execute the piped script
cat > /tmp/proconly.sh
sh /tmp/proconly.sh
')

    if echo "$output" | grep -q "sleep"; then
        log_success "✓ REQ-004: Command line parsed and displayed"
    else
        log_error "✗ REQ-004: Command line not found in output"
        return 1
    fi

    return 0
}

# REQ-005: Process State Detection
test_req_005() {
    log_info "Testing REQ-005: Process State Detection"

    local output
    output=$(docker run --rm -i busybox sh -s < "$PROCONLY_SCRIPT" 2>&1)

    if echo "$output" | grep -qE "\[(R|S|D|Z|T|I|W|X)\]"; then
        log_success "✓ REQ-005: Process state extracted from /proc/[pid]/stat"
    else
        log_error "✗ REQ-005: No valid process states found"
        return 1
    fi

    if echo "$output" | grep -E "PID 1" | grep -qE "\[(R|S|D|Z|T|I|W|X)\]"; then
        log_success "✓ REQ-005: State displayed for PID 1"
    else
        log_error "✗ REQ-005: State not displayed for PID 1"
        return 1
    fi

    return 0
}

# REQ-010: Open File Enumeration
test_req_010() {
    log_info "Testing REQ-010: Open File Enumeration"

    local output
    output=$(cat "$PROCONLY_SCRIPT" | docker run --rm -i busybox sh -c '
# Create a test file and open it
echo "test" > /tmp/testfile.txt
exec 3< /tmp/testfile.txt

# Start background process that keeps a file open
sleep 999 &
sleep_pid=$!
sleep 0.1

# Read and execute the piped script
cat > /tmp/proconly.sh
sh /tmp/proconly.sh
')

    # Check that FD directory is being read
    if echo "$output" | grep -qE "(Open files|File descriptors|FD [0-9]+)"; then
        log_success "✓ REQ-010: File descriptor information displayed"
    else
        log_error "✗ REQ-010: No file descriptor information found"
        return 1
    fi

    # Check that file paths are shown (should see /tmp or standard FDs)
    if echo "$output" | grep -qE "(/tmp|/dev|/proc)"; then
        log_success "✓ REQ-010: File paths resolved from symlinks"
    else
        log_error "✗ REQ-010: File paths not displayed"
        return 1
    fi

    return 0
}

# REQ-011: Socket Detection & Address Resolution
test_req_011() {
    log_info "Testing REQ-011: Socket Detection & Address Resolution"

    local output
    output=$(cat "$PROCONLY_SCRIPT" | docker run --rm -i busybox sh -c '
# Create TCP listener on IPv4
nc -l -p 8080 -s 127.0.0.1 &
sleep 0.2

# Create TCP listener on IPv6 (any address)
nc -l -p 9090 &
sleep 0.2

# Create UDP listener
nc -u -l -p 7070 &
sleep 0.2

# Read and execute the piped script
cat > /tmp/proconly.sh
sh /tmp/proconly.sh
')

    # Check that sockets are detected
    if echo "$output" | grep -q "socket:\["; then
        log_success "✓ REQ-011: Socket file descriptors detected"
    else
        log_error "✗ REQ-011: No sockets detected"
        return 1
    fi

    # Check for TCP protocol identification
    if echo "$output" | grep -qE "(TCP/IPv4|TCP/IPv6)"; then
        log_success "✓ REQ-011: TCP protocol identified"
    else
        log_error "✗ REQ-011: TCP protocol not identified"
        return 1
    fi

    # Check for UDP protocol identification
    if echo "$output" | grep -qE "UDP"; then
        log_success "✓ REQ-011: UDP protocol identified"
    else
        log_error "✗ REQ-011: UDP protocol not identified"
        return 1
    fi

    # Check for state information (LISTEN)
    if echo "$output" | grep -q "LISTEN"; then
        log_success "✓ REQ-011: Socket state displayed"
    else
        log_error "✗ REQ-011: Socket state not displayed"
        return 1
    fi

    # Check for port information
    if echo "$output" | grep -qE ":(8080|9090|7070)"; then
        log_success "✓ REQ-011: Port information displayed"
    else
        log_error "✗ REQ-011: Port information not displayed"
        return 1
    fi

    # Check for IPv4 address parsing (should see 127.0.0.1 or 0.0.0.0)
    if echo "$output" | grep -qE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"; then
        log_success "✓ REQ-011: IPv4 addresses parsed"
    else
        log_error "✗ REQ-011: IPv4 addresses not parsed"
        return 1
    fi

    return 0
}

# Run all requirement tests
test_all_requirements() {
    log_info "Running all EARS requirement tests..."
    echo ""

    local failed=0
    local total=0

    local tests=(
        "test_req_001"
        "test_req_002"
        "test_req_003"
        "test_req_004"
        "test_req_005"
        "test_req_010"
        "test_req_011"
    )

    for test_func in "${tests[@]}"; do
        total=$((total + 1))
        echo ""
        if $test_func; then
            log_success "PASS: $test_func"
        else
            log_error "FAIL: $test_func"
            failed=$((failed + 1))
        fi
    done

    echo ""
    echo "======================================"
    echo "Test Results: $((total - failed))/$total passed"
    echo "======================================"

    if [ $failed -eq 0 ]; then
        log_success "All requirement tests passed!"
        return 0
    else
        log_error "$failed requirement test(s) failed"
        return 1
    fi
}

# Run a specific requirement test
run_requirement_test() {
    local req_id=$1

    case "$req_id" in
        REQ-001)
            test_req_001
            ;;
        REQ-002)
            test_req_002
            ;;
        REQ-003)
            test_req_003
            ;;
        REQ-004)
            test_req_004
            ;;
        REQ-005)
            test_req_005
            ;;
        REQ-010)
            test_req_010
            ;;
        REQ-011)
            test_req_011
            ;;
        all)
            test_all_requirements
            ;;
        *)
            log_error "Unknown requirement: $req_id"
            log_info "Available: REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-010, REQ-011, all"
            exit 1
            ;;
    esac
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

MODE="${1:-run}"
ARG="${2:-all}"

case "$MODE" in
    run)
        log_info "Running proconly.sh in busybox container..."
        docker run --rm -i busybox sh -s < "$PROCONLY_SCRIPT"
        log_success "Script executed successfully"
        ;;

    req)
        run_requirement_test "$ARG"
        ;;

    *)
        log_error "Unknown mode: $MODE"
        echo ""
        usage
        exit 1
        ;;
esac
