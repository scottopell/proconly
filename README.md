# proconly.sh

A copy-pasteable container debugger for minimal environments.

## The Problem

You've `kubectl exec`'d into a production container and need to debug it. But it's Alpine, distroless, or scratch-based:

- No `ps`, `lsof`, or `netstat`
- No package manager
- No network access to install tools
- Just busybox (maybe)

## The Solution

Paste this script. It parses `/proc` directly to show you:

- **Running processes** with PID, state, command line, and executable path
- **Open file descriptors** including files, sockets, and pipes
- **Network connections** with protocol, state, and addresses (TCP/UDP, IPv4/IPv6)
- **Pipe relationships** showing which processes are connected
- **Loaded libraries** via memory-mapped files

## Example Output

```
=== proconly.sh - Process Diagnostics ===

--- Running Processes ---
PID 1 [S]: sh -c nc -l -p 8080 & yes | cat >/dev/null &...
  Exe: /bin/sh
PID 7 [S]: nc -l -p 8080
  Exe: /bin/nc
PID 8 [R]: yes
  Exe: /bin/yes
PID 9 [R]: cat
  Exe: /bin/cat

--- Open File Descriptors ---

PID 7: nc -l -p 8080
  FD 0 -> /dev/null
  FD 3 -> socket:[623750] (TCP/IPv6 LISTEN (IPv6):8080)

PID 8: yes
  FD 1 -> pipe:[618332] (pipe -> PID 9 FD 0)

PID 9: cat
  FD 0 -> pipe:[618332] (pipe -> PID 8 FD 1)
  FD 1 -> /dev/null

--- Memory-Mapped Files ---

PID 7: nc -l -p 8080
  /bin/nc
  /lib/ld-linux-aarch64.so.1
  /lib/libc.so.6

=== Summary: 4 processes, 12 open file descriptors ===
```

Key insights from this output:
- `nc` is listening on port 8080 (TCP/IPv6)
- `yes` (PID 8) is piping to `cat` (PID 9) via pipe 618332
- All processes are using busybox binaries from `/bin/`

## Usage

```bash
# Copy into container and run
cat > /tmp/proconly.sh << 'EOF'
# paste script contents
EOF
sh /tmp/proconly.sh

# Or with full command lines (no truncation)
sh /tmp/proconly.sh --no-truncate
```

## Requirements

- POSIX sh (bash, dash, busybox ash all work)
- Linux `/proc` filesystem
- That's it

## Testing

```bash
# Run all requirement tests
./tests/test-busybox.sh req all

# Test specific requirement
./tests/test-busybox.sh req REQ-PO-001

# Quick manual test in busybox
./tests/test-busybox.sh run
```

## License

MIT

---

## Appendix: Shell Portability Notes

This script targets POSIX sh and must work across multiple shell implementations
including **busybox ash**, **dash**, and **bash**. Below are shell-specific
behaviors discovered during development.

### Substring Extraction

**Problem:** Bash/ash support `${var:offset:length}` but dash does not.

```sh
# Bash/ash - works
hex="0100007F"
echo ${hex:6:2}  # outputs "7F"

# Dash - "Bad substitution" error
```

**Solution:** Use `cut` for POSIX compliance:

```sh
echo "$hex" | cut -c7-8  # works everywhere
```

**Location:** `parse_ipv4_hex()` function

### Function Return Codes with `set -e`

**Problem:** Dash handles `set -e` more strictly than bash/ash. A function
returning non-zero can cause script exit even when called in command
substitution context.

```sh
set -e

lookup_socket() {
    # ... search logic ...
    return 1  # not found
}

# Bash/ash: continues execution, $result is empty
# Dash: exits script immediately
result=$(lookup_socket "$inode")
```

**Solution:** Return 0 when callers check output (not exit code):

```sh
lookup_socket() {
    # ... search logic ...
    # Caller checks if output is empty, so return 0 always
    return 0
}
```

**Location:** `lookup_inet_socket()`, `lookup_unix_socket()` functions

### Safe Constructs

These work consistently across dash, bash, and busybox ash:

- `${#var}` - string length
- `printf "%.Ns"` - truncate to N characters
