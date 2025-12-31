#!/bin/bash
# test-busybox.sh - spEARS requirement testing for proconly.sh
# Tests requirements defined in specs/proconly/requirements.md

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROCONLY_SCRIPT="$PROJECT_ROOT/proconly.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
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

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
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
    echo "Requirements (spEARS format):"
    echo "  REQ-PO-001   - Run diagnostics in any container"
    echo "  REQ-PO-002   - See all running processes"
    echo "  REQ-PO-003   - Understand process state"
    echo "  REQ-PO-004   - Identify what each process is doing"
    echo "  REQ-PO-010   - See what files processes have open"
    echo "  REQ-PO-011   - Identify network connections"
    echo "  all          - Run all requirement tests"
    echo ""
    echo "Examples:"
    echo "  $0 run                # Quick manual execution"
    echo "  $0 req REQ-PO-001     # Test single requirement"
    echo "  $0 req all            # Test all requirements (primary workflow)"
    echo ""
    echo "See specs/proconly/requirements.md for full requirement definitions"
}

if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

# ============================================================================
# spEARS REQUIREMENT TESTS
# See specs/proconly/requirements.md for full requirement definitions
# ============================================================================

# REQ-PO-001: Run Diagnostics in Any Container
test_req_po_001() {
    log_info "Testing REQ-PO-001: Run Diagnostics in Any Container"

    local exit_code=0
    local output
    output=$(docker run --rm -i busybox sh -s < "$PROCONLY_SCRIPT" 2>&1) || exit_code=$?

    if [ $exit_code -eq 0 ]; then
        log_success "✓ REQ-PO-001: Script exits with code 0"
    else
        log_error "✗ REQ-PO-001: Script exited with code $exit_code"
        return 1
    fi

    if [ -n "$output" ]; then
        log_success "✓ REQ-PO-001: Script produces output"
    else
        log_error "✗ REQ-PO-001: No output produced"
        return 1
    fi

    return 0
}

# REQ-PO-002: See All Running Processes
test_req_po_002() {
    log_info "Testing REQ-PO-002: See All Running Processes"

    local output
    output=$(docker run --rm -i busybox sh -s < "$PROCONLY_SCRIPT" 2>&1)

    if echo "$output" | grep -q "PID 1"; then
        log_success "✓ REQ-PO-002: PID 1 (init) discovered"
    else
        log_error "✗ REQ-PO-002: PID 1 not found"
        return 1
    fi

    local pid_count
    pid_count=$(echo "$output" | grep -c "^PID [0-9]" || true)

    if [ "$pid_count" -gt 0 ]; then
        log_success "✓ REQ-PO-002: Discovered $pid_count processes"
    else
        log_error "✗ REQ-PO-002: No processes discovered"
        return 1
    fi

    return 0
}

# REQ-PO-003: Understand Process State
# (Combines old REQ-003 and REQ-005)
test_req_po_003() {
    log_info "Testing REQ-PO-003: Understand Process State"

    local output
    output=$(docker run --rm -i busybox sh -s < "$PROCONLY_SCRIPT" 2>&1)

    # Check PID displayed
    if echo "$output" | grep -qE "PID [0-9]+"; then
        log_success "✓ REQ-PO-003: PID displayed"
    else
        log_error "✗ REQ-PO-003: PID not displayed"
        return 1
    fi

    # Check process state displayed
    if echo "$output" | grep -qE "\[[A-Z?]\]"; then
        log_success "✓ REQ-PO-003: Process state displayed"
    else
        log_error "✗ REQ-PO-003: Process state not displayed"
        return 1
    fi

    # Check command displayed
    if echo "$output" | grep -qE "PID [0-9]+ \[[A-Z?]\]:"; then
        log_success "✓ REQ-PO-003: Command displayed"
    else
        log_error "✗ REQ-PO-003: Command not displayed"
        return 1
    fi

    # Check valid state characters (R/S/D/Z/T/I/W/X)
    if echo "$output" | grep -qE "\[(R|S|D|Z|T|I|W|X)\]"; then
        log_success "✓ REQ-PO-003: Valid process state extracted"
    else
        log_error "✗ REQ-PO-003: No valid process states found"
        return 1
    fi

    # Check state for PID 1 specifically
    if echo "$output" | grep -E "PID 1" | grep -qE "\[(R|S|D|Z|T|I|W|X)\]"; then
        log_success "✓ REQ-PO-003: State displayed for PID 1"
    else
        log_error "✗ REQ-PO-003: State not displayed for PID 1"
        return 1
    fi

    return 0
}

# REQ-PO-004: Identify What Each Process Is Doing
test_req_po_004() {
    log_info "Testing REQ-PO-004: Identify What Each Process Is Doing"

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
        log_success "✓ REQ-PO-004: Command line parsed and displayed"
    else
        log_error "✗ REQ-PO-004: Command line not found in output"
        return 1
    fi

    return 0
}

# REQ-PO-010: See What Files Processes Have Open
test_req_po_010() {
    log_info "Testing REQ-PO-010: See What Files Processes Have Open"

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
        log_success "✓ REQ-PO-010: File descriptor information displayed"
    else
        log_error "✗ REQ-PO-010: No file descriptor information found"
        return 1
    fi

    # Check that file paths are shown (should see /tmp or standard FDs)
    if echo "$output" | grep -qE "(/tmp|/dev|/proc)"; then
        log_success "✓ REQ-PO-010: File paths resolved from symlinks"
    else
        log_error "✗ REQ-PO-010: File paths not displayed"
        return 1
    fi

    return 0
}

# REQ-PO-011: Identify Network Connections
test_req_po_011() {
    log_info "Testing REQ-PO-011: Identify Network Connections"

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
        log_success "✓ REQ-PO-011: Socket file descriptors detected"
    else
        log_error "✗ REQ-PO-011: No sockets detected"
        return 1
    fi

    # Check for TCP protocol identification
    if echo "$output" | grep -qE "(TCP/IPv4|TCP/IPv6)"; then
        log_success "✓ REQ-PO-011: TCP protocol identified"
    else
        log_error "✗ REQ-PO-011: TCP protocol not identified"
        return 1
    fi

    # Check for UDP protocol identification
    if echo "$output" | grep -qE "UDP"; then
        log_success "✓ REQ-PO-011: UDP protocol identified"
    else
        log_error "✗ REQ-PO-011: UDP protocol not identified"
        return 1
    fi

    # Check for state information (LISTEN)
    if echo "$output" | grep -q "LISTEN"; then
        log_success "✓ REQ-PO-011: Socket state displayed"
    else
        log_error "✗ REQ-PO-011: Socket state not displayed"
        return 1
    fi

    # Check for port information
    if echo "$output" | grep -qE ":(8080|9090|7070)"; then
        log_success "✓ REQ-PO-011: Port information displayed"
    else
        log_error "✗ REQ-PO-011: Port information not displayed"
        return 1
    fi

    # Check for IPv4 address parsing (should see 127.0.0.1 or 0.0.0.0)
    if echo "$output" | grep -qE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"; then
        log_success "✓ REQ-PO-011: IPv4 addresses parsed"
    else
        log_error "✗ REQ-PO-011: IPv4 addresses not parsed"
        return 1
    fi

    return 0
}

# Run all requirement tests
test_all_requirements() {
    log_info "Running all spEARS requirement tests..."
    echo ""

    local failed=0
    local total=0

    local tests=(
        "test_req_po_001"
        "test_req_po_002"
        "test_req_po_003"
        "test_req_po_004"
        "test_req_po_010"
        "test_req_po_011"
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

# Map old requirement IDs to new ones (backward compatibility)
map_legacy_req_id() {
    local req_id=$1
    case "$req_id" in
        REQ-001) echo "REQ-PO-001" ;;
        REQ-002) echo "REQ-PO-002" ;;
        REQ-003) echo "REQ-PO-003" ;;
        REQ-004) echo "REQ-PO-004" ;;
        REQ-005) echo "REQ-PO-003" ;;  # Merged into REQ-PO-003
        REQ-010) echo "REQ-PO-010" ;;
        REQ-011) echo "REQ-PO-011" ;;
        *) echo "" ;;
    esac
}

# Run a specific requirement test
run_requirement_test() {
    local req_id=$1

    # Check for legacy ID and map it
    local mapped_id
    mapped_id=$(map_legacy_req_id "$req_id")
    if [ -n "$mapped_id" ]; then
        log_warn "Legacy ID '$req_id' mapped to '$mapped_id'"
        log_warn "Please update to use new spEARS IDs (REQ-PO-XXX)"
        req_id="$mapped_id"
    fi

    case "$req_id" in
        REQ-PO-001)
            test_req_po_001
            ;;
        REQ-PO-002)
            test_req_po_002
            ;;
        REQ-PO-003)
            test_req_po_003
            ;;
        REQ-PO-004)
            test_req_po_004
            ;;
        REQ-PO-010)
            test_req_po_010
            ;;
        REQ-PO-011)
            test_req_po_011
            ;;
        all)
            test_all_requirements
            ;;
        *)
            log_error "Unknown requirement: $req_id"
            log_info "Available: REQ-PO-001, REQ-PO-002, REQ-PO-003, REQ-PO-004, REQ-PO-010, REQ-PO-011, all"
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
