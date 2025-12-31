# Process Diagnostics - Executive Summary

## Requirements Summary

proconly solves a common production debugging problem: you've exec'd into a
minimal container (Alpine, distroless, scratch) and need to understand what's
running. There's no package manager, no network, no strace, no lsof—just
busybox.

Engineers can paste the script into any Linux container and immediately see all
running processes with their state and command lines. For deeper investigation,
the tool shows open file descriptors including network sockets with full address
resolution (TCP/UDP, IPv4/IPv6, listening vs connected, local and remote
endpoints). Output is optimized for dense production environments with long
command lines truncated to 120 characters by default (override with
`--no-truncate`), numeric PID sorting for intuitive navigation, and a summary
footer showing total process and file descriptor counts.

The tool is designed for hostile environments: it handles permission errors
gracefully (showing what's accessible rather than failing), survives process
churn (processes starting/stopping during execution), and works with the most
limited shell environments (POSIX sh, busybox utilities only).

## Technical Summary

proconly parses the Linux `/proc` filesystem directly—no external tools required.
Process discovery iterates numeric directories under `/proc`. Process metadata
comes from `/proc/[pid]/stat` (state), `/proc/[pid]/cmdline` (arguments), and
`/proc/[pid]/comm` (fallback name).

File descriptor enumeration reads `/proc/[pid]/fd/` symlinks. Socket resolution
cross-references socket inodes against `/proc/net/tcp`, `/proc/net/tcp6`,
`/proc/net/udp`, `/proc/net/udp6`, and `/proc/net/unix` to extract protocol,
state, and address information. IPv4 addresses are converted from hex to dotted
decimal notation. The tool also shows the executable binary path via
`/proc/[pid]/exe` and lists loaded libraries by parsing `/proc/[pid]/maps`.

The script is pure POSIX sh with busybox-compatible awk for parsing. Total size
is kept under 400 lines for reliable copy-paste deployment.

## Status Summary

| Requirement | Status | Notes |
|-------------|--------|-------|
| **REQ-PO-001:** Run Diagnostics in Any Container | ✅ Complete | Verified in busybox container |
| **REQ-PO-002:** See All Running Processes | ✅ Complete | Discovers all `/proc/[pid]` entries |
| **REQ-PO-003:** Understand Process State | ✅ Complete | Shows PID, state, command |
| **REQ-PO-004:** Identify What Each Process Is Doing | ✅ Complete | Parses cmdline with comm fallback |
| **REQ-PO-010:** See What Files Processes Have Open | ✅ Complete | Enumerates `/proc/[pid]/fd/` |
| **REQ-PO-011:** Identify Network Connections | ✅ Complete | TCP/UDP/Unix with address resolution |
| **REQ-PO-012:** Trace Inter-Process Communication | ✅ Complete | Cross-references pipe inodes between processes |
| **REQ-PO-013:** Discover Loaded Libraries | ✅ Complete | Parses /proc/[pid]/maps for file-backed mappings |
| **REQ-PO-014:** Find the Actual Binary Running | ✅ Complete | Reads /proc/[pid]/exe symlink |
| **REQ-PO-020:** Graceful Operation Without Root | ✅ Complete | Skips unreadable processes, continues gracefully |
| **REQ-PO-021:** Stable Operation During Churn | ✅ Complete | Handles disappearing processes mid-enumeration |
| **REQ-PO-022:** Reliable Output Despite Bad Data | ✅ Complete | Fallback values for unparseable data |
| **REQ-PO-030:** Work in Minimal Environments | ✅ Complete | POSIX sh, busybox only |
| **REQ-PO-031:** Deploy Without Package Manager | ✅ Complete | Single file, under 400 lines |
| **REQ-PO-040:** Readable Command Lines in Dense Environments | ✅ Complete | 120 char truncation, --no-truncate flag |
| **REQ-PO-041:** Intuitive Process Ordering | ✅ Complete | Numeric PID sorting |
| **REQ-PO-042:** Quick Summary of System State | ✅ Complete | Header and footer with counts |

**Progress:** 17 of 17 complete
