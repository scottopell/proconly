#!/bin/sh
# proconly.sh - A copy-pasteable container debugger
# Parses /proc filesystem to show process info without external tools

set -e

# ============================================================================
# Configuration and Arguments
# ============================================================================

TRUNCATE_CMD=1
CMD_MAX_LEN=120

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --no-truncate)
            TRUNCATE_CMD=0
            ;;
    esac
done

# Truncate command line if needed
# REQ-PO-040: Readable Command Lines in Dense Environments
truncate_cmd() {
    cmd="$1"
    if [ "$TRUNCATE_CMD" -eq 1 ] && [ ${#cmd} -gt $CMD_MAX_LEN ]; then
        printf "%.${CMD_MAX_LEN}s..." "$cmd"
    else
        printf "%s" "$cmd"
    fi
}

# Counters for summary
# REQ-PO-042: Quick Summary of System State
process_count=0
fd_count=0

# ============================================================================
# Helper Functions for Socket Parsing
# ============================================================================

# Parse IPv4 hex address (little-endian) to dotted decimal
# Input: 0100007F (hex), Output: 127.0.0.1
# Uses cut for POSIX compliance (dash doesn't support ${var:n:m} syntax)
parse_ipv4_hex() {
    hex=$1
    # IPv4 stored in little-endian, reverse byte order
    b1=$(printf "%d" 0x$(echo "$hex" | cut -c7-8) 2>/dev/null || echo "0")
    b2=$(printf "%d" 0x$(echo "$hex" | cut -c5-6) 2>/dev/null || echo "0")
    b3=$(printf "%d" 0x$(echo "$hex" | cut -c3-4) 2>/dev/null || echo "0")
    b4=$(printf "%d" 0x$(echo "$hex" | cut -c1-2) 2>/dev/null || echo "0")
    echo "$b1.$b2.$b3.$b4"
}

# Parse hex port to decimal
# Input: 1F90 (hex), Output: 8080
parse_port_hex() {
    hex=$1
    printf "%d" 0x$hex 2>/dev/null || echo "$hex"
}

# Convert TCP state code to name
# Input: 0A, Output: LISTEN
parse_tcp_state() {
    case "$1" in
        01) echo "ESTABLISHED" ;;
        02) echo "SYN_SENT" ;;
        03) echo "SYN_RECV" ;;
        04) echo "FIN_WAIT1" ;;
        05) echo "FIN_WAIT2" ;;
        06) echo "TIME_WAIT" ;;
        07) echo "CLOSE" ;;
        08) echo "CLOSE_WAIT" ;;
        09) echo "LAST_ACK" ;;
        0A) echo "LISTEN" ;;
        0B) echo "CLOSING" ;;
        *) echo "UNKNOWN" ;;
    esac
}

# Lookup inet socket info by inode
# Returns: "protocol local_addr:port [-> remote_addr:port] state"
lookup_inet_socket() {
    inode=$1

    # Check TCP IPv4
    if [ -r /proc/net/tcp ]; then
        result=$(awk -v ino="$inode" '
            $10 == ino {
                split($2, local, ":")
                split($3, remote, ":")
                print "TCP/IPv4", local[1], local[2], remote[1], remote[2], $4
            }
        ' /proc/net/tcp 2>/dev/null | head -1)

        if [ -n "$result" ]; then
            echo "$result"
            return 0
        fi
    fi

    # Check TCP IPv6
    if [ -r /proc/net/tcp6 ]; then
        result=$(awk -v ino="$inode" '
            $10 == ino {
                split($2, local, ":")
                split($3, remote, ":")
                print "TCP/IPv6", local[1], local[2], remote[1], remote[2], $4
            }
        ' /proc/net/tcp6 2>/dev/null | head -1)

        if [ -n "$result" ]; then
            echo "$result"
            return 0
        fi
    fi

    # Check UDP IPv4
    if [ -r /proc/net/udp ]; then
        result=$(awk -v ino="$inode" '
            $10 == ino {
                split($2, local, ":")
                print "UDP/IPv4", local[1], local[2], "none", "none", $4
            }
        ' /proc/net/udp 2>/dev/null | head -1)

        if [ -n "$result" ]; then
            echo "$result"
            return 0
        fi
    fi

    # Check UDP IPv6
    if [ -r /proc/net/udp6 ]; then
        result=$(awk -v ino="$inode" '
            $10 == ino {
                split($2, local, ":")
                print "UDP/IPv6", local[1], local[2], "none", "none", $4
            }
        ' /proc/net/udp6 2>/dev/null | head -1)

        if [ -n "$result" ]; then
            echo "$result"
            return 0
        fi
    fi

    # Return 0 even when not found - callers check output, not exit code
    # This avoids issues with set -e in strict POSIX shells (dash)
    return 0
}

# Lookup unix socket info by inode
# Returns: "Unix path"
lookup_unix_socket() {
    inode=$1

    if [ ! -r /proc/net/unix ]; then
        return 0
    fi

    # Extract path from /proc/net/unix
    awk -v ino="$inode" '
        $7 == ino {
            if ($8 != "") print $8
            else print "(unnamed)"
        }
    ' /proc/net/unix 2>/dev/null | head -1
}

echo "=== proconly.sh - Process Diagnostics ==="
echo ""

# Get sorted list of PIDs
# REQ-PO-041: Intuitive Process Ordering
pids=$(ls -1 /proc 2>/dev/null | grep '^[0-9]*$' | sort -n)

# List all running processes
echo "--- Running Processes ---"
for pid in $pids; do
    pid_dir="/proc/$pid"

    # Skip if we can't read this process
    if [ ! -r "$pid_dir/stat" ]; then
        continue
    fi

    # Read command from cmdline (null-separated, so we need to handle it)
    cmd=""
    if [ -r "$pid_dir/cmdline" ]; then
        cmd=$(tr '\0' ' ' < "$pid_dir/cmdline" 2>/dev/null || echo "")
    fi

    # Fallback to comm if cmdline is empty
    if [ -z "$cmd" ] && [ -r "$pid_dir/comm" ]; then
        cmd=$(cat "$pid_dir/comm" 2>/dev/null || echo "")
    fi

    # Read state from stat file (format: pid (comm) state ...)
    state=""
    if [ -r "$pid_dir/stat" ]; then
        state=$(cat "$pid_dir/stat" 2>/dev/null | cut -d' ' -f3 || echo "?")
    fi

    # REQ-PO-014: Read executable symlink
    exe=""
    if [ -L "$pid_dir/exe" ]; then
        exe=$(readlink "$pid_dir/exe" 2>/dev/null || echo "")
    fi

    # REQ-PO-040: Apply truncation
    cmd_display=$(truncate_cmd "$cmd")
    if [ -n "$exe" ]; then
        echo "PID $pid [$state]: $cmd_display"
        echo "  Exe: $exe"
    else
        echo "PID $pid [$state]: $cmd_display"
    fi

    # REQ-PO-042: Count processes
    process_count=$((process_count + 1))
done

echo ""
echo "--- Open File Descriptors ---"
# REQ-PO-041: Use same sorted PID list
for pid in $pids; do
    pid_dir="/proc/$pid"

    # Skip if we can't read this process's FD directory
    if [ ! -d "$pid_dir/fd" ] || [ ! -r "$pid_dir/fd" ]; then
        continue
    fi

    # Check if there are any FDs to list
    proc_fd_count=0
    for fd in "$pid_dir/fd"/*; do
        if [ -L "$fd" ]; then
            proc_fd_count=$((proc_fd_count + 1))
        fi
    done

    # Skip if no FDs found
    if [ "$proc_fd_count" -eq 0 ]; then
        continue
    fi

    # Get process command for context
    cmd=""
    if [ -r "$pid_dir/cmdline" ]; then
        cmd=$(tr '\0' ' ' < "$pid_dir/cmdline" 2>/dev/null || echo "")
    fi
    if [ -z "$cmd" ] && [ -r "$pid_dir/comm" ]; then
        cmd=$(cat "$pid_dir/comm" 2>/dev/null || echo "")
    fi

    # REQ-PO-040: Apply truncation to FD section header
    cmd_display=$(truncate_cmd "$cmd")
    echo ""
    echo "PID $pid: $cmd_display"

    # List all file descriptors
    for fd in "$pid_dir/fd"/*; do
        if [ -L "$fd" ]; then
            fd_num=$(basename "$fd")
            fd_target=$(readlink "$fd" 2>/dev/null || echo "[unreadable]")

            # Check if this is a socket or pipe
            case "$fd_target" in
                socket:\[*\])
                    # Extract inode from socket:[12345]
                    inode=$(echo "$fd_target" | sed 's/socket:\[\([0-9]*\)\]/\1/')

                    # Try to lookup socket info
                    socket_info=$(lookup_inet_socket "$inode")

                    if [ -n "$socket_info" ]; then
                        # Parse socket info: protocol local_addr local_port remote_addr remote_port state
                        protocol=$(echo "$socket_info" | awk '{print $1}')
                        local_addr_hex=$(echo "$socket_info" | awk '{print $2}')
                        local_port_hex=$(echo "$socket_info" | awk '{print $3}')
                        remote_addr_hex=$(echo "$socket_info" | awk '{print $4}')
                        remote_port_hex=$(echo "$socket_info" | awk '{print $5}')
                        state_hex=$(echo "$socket_info" | awk '{print $6}')

                        # Format based on protocol
                        if echo "$protocol" | grep -q "IPv4"; then
                            local_addr=$(parse_ipv4_hex "$local_addr_hex")
                            local_port=$(parse_port_hex "$local_port_hex")

                            # Check if TCP and has remote connection
                            if echo "$protocol" | grep -q "TCP" && [ "$remote_addr_hex" != "00000000" ]; then
                                remote_addr=$(parse_ipv4_hex "$remote_addr_hex")
                                remote_port=$(parse_port_hex "$remote_port_hex")
                                state=$(parse_tcp_state "$state_hex")
                                echo "  FD $fd_num -> $fd_target ($protocol $state $local_addr:$local_port -> $remote_addr:$remote_port)"
                            else
                                # LISTEN or UDP
                                if echo "$protocol" | grep -q "TCP"; then
                                    state=$(parse_tcp_state "$state_hex")
                                    echo "  FD $fd_num -> $fd_target ($protocol $state $local_addr:$local_port)"
                                else
                                    echo "  FD $fd_num -> $fd_target ($protocol $local_addr:$local_port)"
                                fi
                            fi
                        elif echo "$protocol" | grep -q "IPv6"; then
                            # IPv6 - just show protocol and port
                            local_port=$(parse_port_hex "$local_port_hex")

                            if echo "$protocol" | grep -q "TCP"; then
                                state=$(parse_tcp_state "$state_hex")
                                echo "  FD $fd_num -> $fd_target ($protocol $state (IPv6):$local_port)"
                            else
                                echo "  FD $fd_num -> $fd_target ($protocol (IPv6):$local_port)"
                            fi
                        fi
                    else
                        # Try unix socket
                        unix_path=$(lookup_unix_socket "$inode")
                        if [ -n "$unix_path" ]; then
                            echo "  FD $fd_num -> $fd_target (Unix $unix_path)"
                        else
                            echo "  FD $fd_num -> $fd_target"
                        fi
                    fi
                    ;;
                pipe:\[*\])
                    # Label pipes
                    echo "  FD $fd_num -> $fd_target (pipe)"
                    ;;
                *)
                    # Regular files, devices, etc
                    echo "  FD $fd_num -> $fd_target"
                    ;;
            esac
            # REQ-PO-042: Count file descriptors
            fd_count=$((fd_count + 1))
        fi
    done
done

echo ""
echo "--- Memory-Mapped Files ---"
# REQ-PO-013: Discover Loaded Libraries
# REQ-PO-041: Use same sorted PID list
for pid in $pids; do
    pid_dir="/proc/$pid"

    # Skip if we can't read this process's maps
    if [ ! -r "$pid_dir/maps" ]; then
        continue
    fi

    # Get process command for context
    cmd=""
    if [ -r "$pid_dir/cmdline" ]; then
        cmd=$(tr '\0' ' ' < "$pid_dir/cmdline" 2>/dev/null || echo "")
    fi
    if [ -z "$cmd" ] && [ -r "$pid_dir/comm" ]; then
        cmd=$(cat "$pid_dir/comm" 2>/dev/null || echo "")
    fi

    # Extract unique file-backed mappings (column 6 is the path)
    # Filter to only show actual file paths (not [heap], [stack], etc.)
    mapped_files=$(awk '$6 ~ /^\// { print $6 }' "$pid_dir/maps" 2>/dev/null | sort -u)

    # Skip if no mapped files
    if [ -z "$mapped_files" ]; then
        continue
    fi

    # REQ-PO-040: Apply truncation to maps section header
    cmd_display=$(truncate_cmd "$cmd")
    echo ""
    echo "PID $pid: $cmd_display"
    echo "$mapped_files" | while read -r mfile; do
        echo "  $mfile"
    done
done

echo ""
# REQ-PO-042: Summary footer
echo "=== Summary: $process_count processes, $fd_count open file descriptors ==="
