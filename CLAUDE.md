# proconly - A Copy-Pasteable Container Debugger

---

## ⚠️ MANDATORY DEVELOPMENT WORKFLOW ⚠️

**THIS PROJECT USES EARS → Tests → Code METHODOLOGY**

**YOU MUST FOLLOW THIS WORKFLOW FOR ALL DEVELOPMENT:**

### Step 1: Write EARS Requirement FIRST
**Before writing ANY code**, update `tests/requirements.md`:
- Add a new requirement with unique ID (e.g., REQ-010)
- Use EARS syntax (Ubiquitous, Event-driven, State-driven, Optional, Unwanted behavior)
- Define clear test criteria
- Update the status table

### Step 2: Write Test Function
**After requirement is written**, update `tests/test-busybox.sh`:
- Add `test_req_XXX()` function based on test criteria
- Add to `test_all_requirements()` array
- Run test - **IT MUST FAIL** initially

### Step 3: Verify Test Fails
**Before implementing**, run the test to confirm it fails:
```bash
./tests/test-busybox.sh req REQ-XXX
```

### Step 4: Implement Code
**Only after test exists and fails**, update `proconly.sh`:
- Implement the feature
- Follow busybox/POSIX sh constraints

### Step 5: Verify Test Passes
**After implementing**, run the test again:
```bash
./tests/test-busybox.sh req REQ-XXX
./tests/test-busybox.sh req all  # Ensure no regressions
```

### Step 6: Update Status
Mark requirement as implemented in `tests/requirements.md` status table.

---

## ❌ DO NOT DO THIS:

```
❌ User: "Add support for listing open file descriptors"
❌ Claude: "I'll implement that feature in proconly.sh..."
❌ [Starts writing code without requirements or tests]
```

## ✅ ALWAYS DO THIS:

```
✅ User: "Add support for listing open file descriptors"
✅ Claude: "I'll follow the EARS → Tests → Code workflow:
           1. First, let me write REQ-010 in tests/requirements.md
           2. Then, I'll write test_req_010() in test-busybox.sh
           3. I'll verify the test fails
           4. Then implement the feature in proconly.sh
           5. Finally verify the test passes"
```

---

## Problem Statement

When debugging production containers that are built from minimal base images (Alpine, distroless, etc.), you often find yourself in an environment with:
- No network access
- No package manager
- Only busybox utilities available
- No debugging tools installed

The traditional workflow of "install tools via package manager" is impossible. You need diagnostic capabilities NOW, delivered via copy-paste into your shell.

## Project Goal

Build a single-file, self-contained script that provides essential process and file descriptor diagnostics using only `/proc` filesystem parsing. The tool must work in the most minimal busybox environment and be deliverable by pasting text into a shell.

## Target Use Case

**Persona**: Senior software engineer (10+ YOE) with container/scripting familiarity
**Scenario**: `kubectl exec` or `docker exec` into a production container with limited environment
**Delivery**: `cat > proconly.sh` + paste clipboard + `sh proconly.sh`

## Core Features

### Must Have
1. **List Running Processes**
   - Parse `/proc/[pid]/` directories
   - Show PID, command, state

2. **Open File Descriptors**
   - Parse `/proc/[pid]/fd/` symlinks
   - Show what files each process has open

3. **Process Executables**
   - Parse `/proc/[pid]/exe` symlinks
   - Show the binary path for each running process

4. **Advanced File Descriptors**
   - Detect and label sockets (unix/inet)
   - Identify pipes
   - Show memory-mapped files from `/proc/[pid]/maps`

### Nice to Have
- Network connections (from `/proc/[pid]/net/`)
- Environment variables (from `/proc/[pid]/environ`)
- Command-line arguments (from `/proc/[pid]/cmdline`)
- Working directory (from `/proc/[pid]/cwd`)
- Resource usage (from `/proc/[pid]/status`)

## Constraints

### Hard Requirements
- **Busybox-only**: No bash, no extended utilities, only what's in busybox
- **Copy-pasteable**: Single file, must be small enough to paste into terminal
- **No dependencies**: Cannot assume python, perl, awk beyond busybox versions
- **Human-readable output**: Simple text format, optimized for reading in terminal

### Implementation Language
- **Primary**: Shell script (POSIX sh)
- **Alternative**: Python (if available in minimal containers, but cannot be assumed)
- **No**: Compiled binaries (not copy-pasteable)

### Output Format
- Plain text, human-readable
- Simple structure to minimize lines of code
- No JSON/XML (not the use case)
- Should be scannable at a glance

## Non-Goals

- Real-time monitoring (just snapshots)
- Pretty colors/formatting (may not render in all terminals)
- Interactive UI (keep it simple)
- Cross-platform support (Linux-only via `/proc`)
- Performance optimization (correctness over speed)

## Implementation Approach

**CRITICAL: Always follow EARS → Tests → Code workflow (see mandatory workflow above)**

When implementing features:

1. **Requirements First**: Write EARS requirement in `tests/requirements.md`
2. **Tests Second**: Write test in `tests/test-busybox.sh`, verify it fails
3. **Code Last**: Implement in `proconly.sh` using:
   - Pure shell script with busybox utilities
   - Direct `/proc` filesystem parsing (text parsing)
   - Keep total script under ~200-300 lines for easy pasting
   - Generous comments (self-documenting for when you paste it 6 months later)
   - Graceful degradation (if `/proc/[pid]/maps` is inaccessible, skip it)
4. **Verify**: Run tests to confirm passing, check for regressions

## Testing Environment

**Use the requirement-based test harness for ALL testing:**

```bash
# Primary testing workflow
./tests/test-busybox.sh req all        # Run all requirement tests
./tests/test-busybox.sh req REQ-XXX    # Run specific requirement test

# Quick manual checks
./tests/test-busybox.sh run            # Execute script in busybox
```

**Read these files before starting development:**
- `tests/requirements.md` - All EARS requirements with test criteria
- `tests/README.md` - Test harness documentation
- `tests/test-busybox.sh` - Test implementation examples

## Future Considerations

- Could expand to track other `/proc` data sources
- Might add filtering/search capabilities
- Could create companion scripts for specific scenarios (network debugging, memory analysis)
- Version for different minimal environments (busybox vs distroless)

## Directory Structure

```
.
├── CLAUDE.md               # This file - project overview & MANDATORY workflow
├── README.md               # User-facing documentation
├── proconly.sh             # Main script implementation
└── tests/
    ├── requirements.md     # EARS requirements (ALWAYS UPDATE FIRST)
    ├── test-busybox.sh     # Test harness (req/run modes)
    └── README.md           # Test harness documentation
```

**Key Files for Development:**
1. **tests/requirements.md** - Start here, write requirements FIRST
2. **tests/test-busybox.sh** - Write tests SECOND (see existing test_req_XXX functions)
3. **proconly.sh** - Write implementation LAST

## Development Notes

### WORKFLOW ENFORCEMENT

**⚠️ NEVER start coding without requirements and tests ⚠️**

When asked to implement a feature:
1. Acknowledge you'll follow EARS → Tests → Code workflow
2. Open `tests/requirements.md` and write/update requirement FIRST
3. Open `tests/test-busybox.sh` and write test SECOND (verify it fails)
4. Open `proconly.sh` and implement LAST
5. Run `./tests/test-busybox.sh req all` to verify

**If you catch yourself editing proconly.sh before writing a requirement: STOP**

### Technical Constraints

- **Test in busybox**: Use `./tests/test-busybox.sh` harness, not local shell
- **Avoid bashisms**: No `[[`, no `{1..10}`, no process substitution, no arrays
- **Limited utilities**: busybox awk is limited, busybox sed is limited
- **Kernel compatibility**: Use `/proc` paths that exist in kernel 3.x+
- **Line count**: Keep script under 300 lines for copy-paste deliverability

### EARS Best Practices

- **Requirement IDs**: Use sequential IDs (REQ-001, REQ-002, etc.)
- **Test criteria**: Be specific, measurable, testable
- **One requirement**: One clear thing per requirement (atomic)
- **Test functions**: Map 1:1 to requirements (test_req_001 tests REQ-001)
- **Status tracking**: Update requirements.md table as you implement

### Common Mistakes to Avoid

❌ Implementing a feature without a requirement
❌ Writing code before writing the test
❌ Not running tests after implementing
❌ Skipping the "verify test fails" step
❌ Testing locally instead of in busybox container

### Quick Reference

```bash
# Start feature work
vim tests/requirements.md        # Write requirement FIRST
vim tests/test-busybox.sh        # Write test SECOND
./tests/test-busybox.sh req REQ-XXX  # Verify test FAILS
vim proconly.sh                  # Implement THIRD
./tests/test-busybox.sh req REQ-XXX  # Verify test PASSES
./tests/test-busybox.sh req all  # Check for regressions
```

---

## 🔒 Final Checklist Before Starting Any Work

Before implementing ANY feature, answer these questions:

1. ✅ Have I read `tests/requirements.md` to see existing requirements?
2. ✅ Have I written a new EARS requirement with unique ID?
3. ✅ Have I defined clear, testable criteria in the requirement?
4. ✅ Have I written a `test_req_XXX()` function in test-busybox.sh?
5. ✅ Have I run the test to confirm it FAILS?

**If you answered NO to any of these: DO NOT write code yet.**

**If you answered YES to all: Proceed with implementation.**

---

Remember: The goal is **working, tested, documented features** - not just code that compiles.
