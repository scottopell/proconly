# Process Diagnostics - Technical Design

## Architecture Overview

proconly.sh is a single-file shell script with three logical sections:

1. **Helper Functions** - Socket parsing utilities (REQ-PO-011)
2. **Process Enumeration** - Iterate `/proc/[pid]` directories (REQ-PO-002, REQ-PO-003, REQ-PO-004)
3. **File Descriptor Enumeration** - Read `/proc/[pid]/fd/` with socket resolution (REQ-PO-010, REQ-PO-011)

Data flows linearly: discover processes → display process info → enumerate FDs per process → resolve socket details.

## Data Sources

All data comes from the Linux `/proc` filesystem:

| Path | Purpose | Requirements |
|------|---------|--------------|
| `/proc/[pid]/` | Process existence | REQ-PO-002 |
| `/proc/[pid]/stat` | Process state | REQ-PO-003 |
| `/proc/[pid]/cmdline` | Command line args | REQ-PO-004 |
| `/proc/[pid]/comm` | Process name fallback | REQ-PO-004 |
| `/proc/[pid]/fd/` | Open file descriptors | REQ-PO-010 |
| `/proc/[pid]/exe` | Executable path | REQ-PO-014 |
| `/proc/[pid]/maps` | Memory mappings | REQ-PO-013 |
| `/proc/net/tcp` | TCP IPv4 connections | REQ-PO-011 |
| `/proc/net/tcp6` | TCP IPv6 connections | REQ-PO-011 |
| `/proc/net/udp` | UDP IPv4 sockets | REQ-PO-011 |
| `/proc/net/udp6` | UDP IPv6 sockets | REQ-PO-011 |
| `/proc/net/unix` | Unix domain sockets | REQ-PO-011 |

## Socket Resolution Strategy

Socket file descriptors appear as `socket:[inode]` symlinks. Resolution requires
cross-referencing the inode against `/proc/net/*` tables.

### Resolution Order (REQ-PO-011)

1. Check `/proc/net/tcp` for TCP IPv4 match on column 10 (inode)
2. Check `/proc/net/tcp6` for TCP IPv6 match
3. Check `/proc/net/udp` for UDP IPv4 match
4. Check `/proc/net/udp6` for UDP IPv6 match
5. Check `/proc/net/unix` for Unix socket match on column 7 (inode)
6. If no match found, display raw `socket:[inode]`

### Address Parsing (REQ-PO-011)

IPv4 addresses in `/proc/net/*` are stored as 8-character hex strings in
little-endian byte order:

```
0100007F → 7F 00 00 01 → 127.0.0.1
```

Ports are stored as 4-character hex strings in big-endian:

```
1F90 → 8080
```

TCP states are stored as 2-character hex codes:

```
0A → LISTEN
01 → ESTABLISHED
06 → TIME_WAIT
```

### IPv6 Handling (REQ-PO-011)

IPv6 addresses are 32-character hex strings. Current implementation labels them
as `(IPv6)` with port number only. Full address parsing is deferred due to
complexity and limited busybox printf support.

## Error Handling Strategy

### Permission Errors (REQ-PO-020)

The script uses defensive checks before reading:

```
if [ ! -r "$pid_dir/stat" ]; then continue; fi
```

This pattern skips inaccessible processes rather than failing.

### Race Conditions (REQ-PO-021)

**Current gap:** The script uses `set -e` which exits on any error. Race
conditions where a process exits mid-enumeration can cause premature exit.

**Planned approach:** Remove `set -e` and add explicit error suppression:

```
cmd=$(tr '\0' ' ' < "$pid_dir/cmdline" 2>/dev/null) || cmd=""
```

### Invalid Data (REQ-PO-022)

**Current gap:** Parsing assumes well-formed data. Malformed `/proc/[pid]/stat`
can cause incorrect output.

**Planned approach:** Add validation and fallback values for each parsed field.

## Component Details

### Helper Functions

| Function | Purpose | Requirements |
|----------|---------|--------------|
| `parse_ipv4_hex()` | Convert hex address to dotted decimal | REQ-PO-011 |
| `parse_port_hex()` | Convert hex port to decimal | REQ-PO-011 |
| `parse_tcp_state()` | Convert state code to name | REQ-PO-011 |
| `lookup_inet_socket()` | Find socket in TCP/UDP tables | REQ-PO-011 |
| `lookup_unix_socket()` | Find socket in unix table | REQ-PO-011 |

### Output Format

Process listing (REQ-PO-002, REQ-PO-003, REQ-PO-004):

```
PID 1 [S]: /sbin/init
PID 123 [R]: nginx -g daemon off;
```

File descriptor listing (REQ-PO-010, REQ-PO-011):

```
PID 123: nginx -g daemon off;
  FD 0 -> /dev/null
  FD 3 -> socket:[12345] (TCP/IPv4 LISTEN 0.0.0.0:80)
  FD 5 -> socket:[12346] (Unix /var/run/nginx.sock)
```

## Implementation Notes

### REQ-PO-001: Run Diagnostics in Any Container

- Script uses `#!/bin/sh` shebang for POSIX compatibility
- All utilities are busybox-compatible: `cat`, `tr`, `cut`, `awk`, `sed`, `basename`, `readlink`
- Script exits with code 0 on successful completion

### REQ-PO-002: See All Running Processes

- Process discovery via glob pattern: `/proc/[0-9]*`
- Numeric directories represent PIDs
- Glob handles arbitrary number of processes without external tools

### REQ-PO-003: Understand Process State

- State extracted from `/proc/[pid]/stat` field 3
- Format: `pid (comm) state ...` - state is single character after closing paren
- Current implementation uses `cut -d' ' -f3` which works for simple comm names
- **Gap:** Commands with spaces in name may cause incorrect field extraction

### REQ-PO-004: Identify What Each Process Is Doing

- Primary source: `/proc/[pid]/cmdline` with null bytes converted to spaces via `tr '\0' ' '`
- Fallback: `/proc/[pid]/comm` for kernel threads and processes without cmdline

### REQ-PO-010: See What Files Processes Have Open

- Enumerate `/proc/[pid]/fd/` directory entries
- Each entry is a symlink; `readlink` resolves to target
- Skip processes where fd directory is unreadable

### REQ-PO-011: Identify Network Connections

- Socket detection via pattern match on `socket:[*]`
- Inode extraction via sed: `sed 's/socket:\[\([0-9]*\)\]/\1/'`
- Cross-reference against `/proc/net/{tcp,tcp6,udp,udp6,unix}`
- AWK used for column extraction from proc tables

### REQ-PO-012: Trace Inter-Process Communication

**Not yet implemented.**

Current code detects `pipe:[inode]` pattern but only labels it. Future work:
cross-reference pipe inodes between processes to show pipe relationships.

### REQ-PO-013: Discover Loaded Libraries

**Not yet implemented.**

Will parse `/proc/[pid]/maps` and extract file paths from mapped regions. Filter
to show only file-backed mappings (those with pathname column populated).

### REQ-PO-014: Find the Actual Binary Running

**Not yet implemented.**

Will read `/proc/[pid]/exe` symlink. Handle `(deleted)` suffix for binaries
replaced after process start.

### REQ-PO-020: Graceful Operation Without Root

- Pre-check readability before accessing proc entries
- Continue loop on permission failures
- **Gap:** Some error paths still cause script exit due to `set -e`

### REQ-PO-021: Stable Operation During Churn

**Not yet implemented.**

Need to remove `set -e` and add explicit error handling on all proc reads.

### REQ-PO-022: Reliable Output Despite Bad Data

**Not yet implemented.**

Need to add validation for:
- `/proc/[pid]/stat` format (handle commands with spaces/parens)
- Hex address parsing (handle malformed strings)
- Socket table format (handle missing columns)

### REQ-PO-030: Work in Minimal Environments

- No bash-isms: no `[[`, no arrays, no process substitution
- AWK usage limited to column extraction (busybox awk compatible)
- No external tools beyond busybox set

### REQ-PO-031: Deploy Without Package Manager

- Single file at ~285 lines (under 400 line target)
- No imports or dependencies
- Self-contained with all helper functions inline

## File Locations

| Component | Location |
|-----------|----------|
| Main script | `proconly.sh` |
| Test harness | `tests/test-busybox.sh` |
| Requirements (old) | `tests/requirements.md` |
| Requirements (spEARS) | `specs/proconly/requirements.md` |

## Trade-offs and Decisions

### Why shell script over Python?

Python isn't guaranteed in minimal containers. Busybox sh is nearly universal.
The trade-off is more verbose parsing code but guaranteed availability.

### Why not parse IPv6 addresses fully?

Busybox printf has limited format specifier support. Full IPv6 parsing would
require significant additional code for limited benefit. Most debugging focuses
on IPv4 or just needs to know "it's IPv6 on port X."

### Why linear output instead of structured data?

Target users are reading output in a terminal during live debugging. Human
scannable text beats JSON/YAML for this use case. Structured output would add
parsing complexity without benefiting the primary use case.
