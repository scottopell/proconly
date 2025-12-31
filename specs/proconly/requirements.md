# Process Diagnostics for Minimal Containers

## User Story

As a senior engineer debugging a production container, I need to inspect running
processes and their resources (files, sockets, pipes) so that I can diagnose
issues without installing additional tools.

## Requirements

### REQ-PO-001: Run Diagnostics in Any Container

THE SYSTEM SHALL execute successfully in a busybox container environment

THE SYSTEM SHALL produce diagnostic output without errors

**Rationale:** Engineers often exec into containers that have no package manager,
no network access, and only busybox utilities. They need a tool that works
immediately without installation steps.

---

### REQ-PO-002: See All Running Processes

WHEN the script executes
THE SYSTEM SHALL list all running processes accessible via `/proc`

WHEN PID 1 exists
THE SYSTEM SHALL include it in the process list

**Rationale:** Understanding what's running is the first step in any debugging
session. Engineers need a complete picture of all processes, not just their own.

---

### REQ-PO-003: Understand Process State

WHEN displaying a process
THE SYSTEM SHALL show the PID, process state, and command

WHEN a process state is available
THE SYSTEM SHALL display the state character (R/S/D/Z/T)

WHEN a process state cannot be determined
THE SYSTEM SHALL display a fallback indicator

**Rationale:** Process state reveals whether something is running, sleeping,
waiting on I/O, or zombied. This is critical for diagnosing hangs and resource
contention.

---

### REQ-PO-004: Identify What Each Process Is Doing

WHEN a process has command line arguments
THE SYSTEM SHALL display them as space-separated text

WHEN a process has no command line arguments
THE SYSTEM SHALL fall back to the process name from `/proc/[pid]/comm`

**Rationale:** Command line arguments reveal configuration, targets, and
operational mode. Engineers need this to understand what a process is actually
doing versus just its binary name.

---

### REQ-PO-010: See What Files Processes Have Open

WHEN displaying process details
THE SYSTEM SHALL enumerate open file descriptors

WHEN a file descriptor points to a regular file
THE SYSTEM SHALL display the file path

**Rationale:** Open files reveal configuration files, log files, data files, and
lock files. This helps engineers understand resource usage and potential file
locking issues.

---

### REQ-PO-011: Identify Network Connections

WHEN a process has open TCP sockets
THE SYSTEM SHALL display the protocol (TCP/IPv4 or TCP/IPv6), state, local
address:port, and remote address:port when applicable

WHEN a process has open UDP sockets
THE SYSTEM SHALL display the protocol (UDP/IPv4 or UDP/IPv6) and local
address:port

WHEN a process has open Unix domain sockets
THE SYSTEM SHALL display the socket type and filesystem path when available

WHEN an IPv4 address is detected
THE SYSTEM SHALL display it in dotted decimal notation

WHEN an IPv6 socket is detected
THE SYSTEM SHALL label it with the protocol

**Rationale:** Network connections are often the key to understanding service
behavior. Engineers need to see what's listening, what's connected, and to
where—especially when debugging connectivity issues.

---

### REQ-PO-012: Trace Inter-Process Communication

WHEN a process has open pipes
THE SYSTEM SHALL identify and label them as pipes

**Rationale:** Pipes connect processes together. Understanding pipe relationships
helps engineers trace data flow between processes in a pipeline.

---

### REQ-PO-013: Discover Loaded Libraries and Mapped Files

WHERE `/proc/[pid]/maps` is readable
THE SYSTEM SHALL list memory-mapped files

WHEN a memory mapping has an associated file path
THE SYSTEM SHALL display that path

**Rationale:** Memory-mapped files reveal shared libraries, mapped data files,
and memory-mapped I/O. This helps diagnose missing libraries and unexpected
dependencies.

---

### REQ-PO-014: Find the Actual Binary Running

WHEN displaying process details
THE SYSTEM SHALL show the executable binary path from `/proc/[pid]/exe`

WHEN an executable has been deleted
THE SYSTEM SHALL indicate this (e.g., showing "(deleted)")

**Rationale:** The actual binary path reveals what code is running, which may
differ from the command name. Deleted binaries indicate in-place upgrades or
compromised systems.

---

### REQ-PO-020: Graceful Operation Without Root Access

IF a `/proc/[pid]/` entry is not readable due to permissions
THE SYSTEM SHALL skip that process without displaying an error

IF file descriptors cannot be read due to permissions
THE SYSTEM SHALL continue processing other available information

**Rationale:** Engineers often don't have root access in production containers.
The tool should show everything accessible rather than failing on the first
permission error.

---

### REQ-PO-021: Stable Operation During Process Churn

IF a process exits while the script is running
THE SYSTEM SHALL continue processing remaining processes

IF a `/proc/[pid]/` entry disappears mid-read
THE SYSTEM SHALL handle the race condition gracefully

**Rationale:** Production systems have processes starting and stopping
constantly. The diagnostic tool must handle this churn without crashing or
producing misleading errors.

---

### REQ-PO-022: Reliable Output Despite Corrupted Data

IF `/proc/[pid]/stat` contains unparseable data
THE SYSTEM SHALL display fallback values

IF `/proc/[pid]/cmdline` contains invalid data
THE SYSTEM SHALL display a placeholder like "[unknown]"

**Rationale:** Kernel bugs, race conditions, or unusual processes may produce
unexpected proc data. The tool should degrade gracefully rather than crash.

---

### REQ-PO-030: Work in Minimal Container Environments

THE SYSTEM SHALL use only POSIX sh syntax

THE SYSTEM SHALL NOT use bash-specific constructs (`[[`, `{1..10}`, arrays,
process substitution)

THE SYSTEM SHALL rely only on utilities available in busybox

**Rationale:** Minimal containers (Alpine, distroless) only have busybox. The
tool must work with the lowest common denominator of shell environments.

---

### REQ-PO-031: Deploy Without Package Manager

THE SYSTEM SHALL be a single file under 400 lines

THE SYSTEM SHALL have no binary dependencies

THE SYSTEM SHALL be deployable via copy-paste into a terminal

**Rationale:** When you can't `apt install` or `apk add`, copy-paste is your
only deployment mechanism. The tool must be small enough to paste reliably.

---
