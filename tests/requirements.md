# Requirements for proconly.sh

This document defines requirements using EARS (Easy Approach to Requirements Syntax) notation.

## EARS Pattern Reference
- **Ubiquitous**: The system shall [requirement]
- **Event-driven**: WHEN [trigger], the system shall [requirement]
- **State-driven**: WHILE [state], the system shall [requirement]
- **Optional feature**: WHERE [feature], the system shall [requirement]
- **Unwanted behavior**: IF [condition], THEN the system shall [requirement]

---

## Core Requirements

### REQ-001: Script Execution
**Type**: Ubiquitous
**Requirement**: The script shall execute successfully in a busybox container environment.

**Test Criteria**:
- Script exits with code 0
- No syntax errors in busybox sh interpreter
- Output is produced

---

### REQ-002: Process Discovery
**Type**: Ubiquitous
**Requirement**: The script shall list all running processes accessible in `/proc`.

**Test Criteria**:
- All numeric directories in `/proc` are discovered
- At minimum, PID 1 (init) is listed
- Process list includes PIDs for all running processes

---

### REQ-003: Process Information Display
**Type**: Ubiquitous
**Requirement**: The script shall display PID, state, and command for each discovered process.

**Test Criteria**:
- Output contains PID numbers
- Output contains process state (R/S/D/Z/T)
- Output contains command line or process name
- Format is human-readable

---

### REQ-004: Command Line Parsing
**Type**: Ubiquitous
**Requirement**: The script shall parse process command lines from `/proc/[pid]/cmdline`.

**Test Criteria**:
- Null-separated arguments are converted to space-separated
- Empty cmdline falls back to `/proc/[pid]/comm`
- Command line is displayed for user processes

---

### REQ-005: Process State Detection
**Type**: Ubiquitous
**Requirement**: The script shall extract process state from `/proc/[pid]/stat`.

**Test Criteria**:
- State character is extracted (R/S/D/Z/T/etc)
- State is displayed in output
- Invalid or missing state shows fallback indicator

---

## File Descriptor Requirements

### REQ-010: Open File Enumeration
**Type**: Ubiquitous
**Requirement**: The script shall enumerate open file descriptors from `/proc/[pid]/fd/`.

**Test Criteria**:
- FD directory is read for each process
- Symlinks are followed to identify file paths
- Regular files are distinguished from special files

---

### REQ-011: Socket Detection & Address Resolution
**Type**: Event-driven
**Requirement**: WHEN a process has open sockets, the script shall identify socket type (TCP/UDP/Unix), protocol version (IPv4/IPv6), state, and address:port information.

**Test Criteria**:
- Socket file descriptors are detected (`socket:[inode]` format)
- TCP sockets show: protocol (TCP/IPv4 or TCP/IPv6), state (LISTEN/ESTABLISHED/etc), local address:port, remote address:port when applicable
- UDP sockets show: protocol (UDP/IPv4 or UDP/IPv6), local address:port
- Unix domain sockets show: socket type and filesystem path when available
- IPv4 addresses are fully parsed and displayed as dotted decimal notation
- IPv6 sockets are labeled with protocol but addresses shown as "(IPv6)" placeholder
- Output format: `FD N -> socket:[inode] (TYPE/PROTOCOL STATE addr:port)`

---

### REQ-012: Pipe Detection
**Type**: Event-driven
**Requirement**: WHEN a process has open pipes, the script shall identify and label them as pipes.

**Test Criteria**:
- Pipe file descriptors are detected (pipe:[inode] format)
- Pipes are labeled distinctly from regular files

---

### REQ-013: Memory-Mapped File Discovery
**Type**: Optional feature
**Requirement**: WHERE `/proc/[pid]/maps` is readable, the script shall list memory-mapped files.

**Test Criteria**:
- `/proc/[pid]/maps` is parsed when accessible
- File paths are extracted from mapping entries
- Mapped files are displayed with appropriate context

---

### REQ-014: Executable Binary Identification
**Type**: Ubiquitous
**Requirement**: The script shall identify the executable binary path from `/proc/[pid]/exe`.

**Test Criteria**:
- `/proc/[pid]/exe` symlink is followed
- Binary path is displayed
- Deleted binaries are indicated (e.g., `/path/to/binary (deleted)`)

---

## Error Handling Requirements

### REQ-020: Permission Denied Handling
**Type**: Unwanted behavior
**Requirement**: IF `/proc/[pid]/` is not readable due to permissions, THEN the script shall skip that process without error.

**Test Criteria**:
- Script does not exit on permission errors
- Unreadable processes are silently skipped
- No error messages for expected permission failures

---

### REQ-021: Missing Proc Entry Handling
**Type**: Unwanted behavior
**Requirement**: IF a `/proc/[pid]/` entry disappears during script execution, THEN the script shall continue processing remaining processes.

**Test Criteria**:
- Race conditions (process exits mid-script) don't crash script
- Script continues after encountering missing entries
- Exit code remains 0

---

### REQ-022: Invalid Proc Data Handling
**Type**: Unwanted behavior
**Requirement**: IF `/proc/[pid]/stat` or `/proc/[pid]/cmdline` contains invalid data, THEN the script shall display fallback information.

**Test Criteria**:
- Unparseable data doesn't crash script
- Fallback values are shown (e.g., "?" for state, "[unknown]" for command)
- Script continues processing other processes

---

## Compatibility Requirements

### REQ-030: Busybox Compatibility
**Type**: Ubiquitous
**Requirement**: The script shall use only POSIX sh syntax and busybox-compatible utilities.

**Test Criteria**:
- No bash-specific syntax (no `[[`, `{1..10}`, etc)
- Only busybox utilities used (limited awk, sed)
- Script runs in `busybox sh` environment

---

### REQ-031: Copy-Paste Deliverability
**Type**: Ubiquitous
**Requirement**: The script shall be deliverable via copy-paste into a terminal.

**Test Criteria**:
- Total script size under 400 lines
- No binary dependencies
- Can be pasted into `cat > script.sh` and executed

---

## Test Scenarios to Requirements Mapping

### Scenario: `basic`
Tests: REQ-001, REQ-002, REQ-003, REQ-004, REQ-005

### Scenario: `files`
Tests: REQ-010, REQ-020

### Scenario: `sockets`
Tests: REQ-011

### Scenario: `mixed`
Tests: REQ-010, REQ-011, REQ-012, REQ-021

---

## Implementation Priority

**Phase 1 (MVP)**: REQ-001 through REQ-005, REQ-030, REQ-031
**Phase 2 (File Descriptors)**: REQ-010, REQ-014
**Phase 3 (Advanced FDs)**: REQ-011, REQ-012, REQ-013
**Phase 4 (Robustness)**: REQ-020, REQ-021, REQ-022

---

## Requirement Status

| ID | Status | Implemented | Tested |
|----|--------|-------------|--------|
| REQ-001 | ✅ | Yes | Yes |
| REQ-002 | ✅ | Yes | Yes |
| REQ-003 | ✅ | Yes | Yes |
| REQ-004 | ✅ | Yes | Yes |
| REQ-005 | ✅ | Yes | Yes |
| REQ-010 | ✅ | Yes | Yes |
| REQ-011 | ✅ | Yes | Yes |
| REQ-012 | ❌ | No | No |
| REQ-013 | ❌ | No | No |
| REQ-014 | ❌ | No | No |
| REQ-020 | 🟡 | Partial | No |
| REQ-021 | ❌ | No | No |
| REQ-022 | ❌ | No | No |
| REQ-030 | ✅ | Yes | Yes |
| REQ-031 | ✅ | Yes | No |
