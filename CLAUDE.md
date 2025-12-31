# proconly - A Copy-Pasteable Container Debugger

---

## Development Methodology

**This project uses spEARS (Simple Project with EARS).**

For full methodology details, see:
- `SPEARS.md` - Complete methodology reference
- `SPEARS_AGENT.md` - Agent workflow rules and checklists

---

## ⚠️ MANDATORY WORKFLOW ⚠️

**Requirements → Design → Tests → Code**

### Before ANY Implementation

1. **Read specs first**: Check `specs/proconly/requirements.md` for existing requirements
2. **Write requirement**: Add EARS statement to `specs/proconly/requirements.md`
3. **Update design**: Document approach in `specs/proconly/design.md`
4. **Write test**: Add test to `tests/test-busybox.sh`, verify it FAILS
5. **Implement**: Update `proconly.sh`
6. **Verify**: Run tests, confirm passing
7. **Update status**: Mark complete in `specs/proconly/executive.md`

### Quick Reference

```bash
# Requirement IDs use format: REQ-PO-XXX (e.g., REQ-PO-015)

# Testing workflow
./tests/test-busybox.sh req REQ-PO-XXX  # Run specific test
./tests/test-busybox.sh req all          # Run all tests
./tests/test-busybox.sh run              # Manual execution in busybox
```

---

## ❌ DO NOT DO THIS:

```
❌ User: "Add pipe relationship tracing"
❌ Claude: "I'll implement that in proconly.sh..."
❌ [Starts writing code without requirements]
```

## ✅ ALWAYS DO THIS:

```
✅ User: "Add pipe relationship tracing"
✅ Claude: "I'll follow spEARS workflow:
           1. Check specs/proconly/requirements.md - found REQ-PO-012
           2. Update specs/proconly/design.md with approach
           3. Write test in test-busybox.sh, verify it fails
           4. Implement in proconly.sh
           5. Verify test passes
           6. Update status in specs/proconly/executive.md"
```

---

## Project Overview

### Problem Statement

When debugging production containers built from minimal base images (Alpine,
distroless, etc.), you often find yourself in an environment with:
- No network access
- No package manager
- Only busybox utilities available
- No debugging tools installed

The traditional workflow of "install tools via package manager" is impossible.
You need diagnostic capabilities NOW, delivered via copy-paste into your shell.

### Goal

Build a single-file, self-contained script that provides essential process and
file descriptor diagnostics using only `/proc` filesystem parsing. The tool must
work in the most minimal busybox environment and be deliverable by pasting text
into a shell.

### Target Use Case

**Persona**: Senior software engineer (10+ YOE) with container/scripting familiarity
**Scenario**: `kubectl exec` or `docker exec` into a production container
**Delivery**: `cat > proconly.sh` + paste clipboard + `sh proconly.sh`

---

## Technical Constraints

### Hard Requirements
- **Busybox-only**: No bash, no extended utilities, only what's in busybox
- **Copy-pasteable**: Single file, under 400 lines
- **No dependencies**: Cannot assume python, perl, awk beyond busybox versions
- **Human-readable output**: Plain text, optimized for terminal reading

### Shell Constraints
- **POSIX sh only**: No `[[`, no `{1..10}`, no process substitution, no arrays
- **Limited utilities**: busybox awk/sed have restrictions
- **Kernel compatibility**: Use `/proc` paths that exist in kernel 3.x+

### Testing
- **Always test in busybox**: Use `./tests/test-busybox.sh` harness
- **Never test locally**: Local shell may have features busybox lacks

---

## Directory Structure

```
.
├── CLAUDE.md                        # This file - project overview
├── SPEARS.md                        # spEARS methodology reference
├── SPEARS_AGENT.md                  # Agent workflow rules
├── README.md                        # User-facing documentation
├── proconly.sh                      # Main script implementation
├── specs/
│   └── proconly/
│       ├── requirements.md          # EARS requirements (WHAT)
│       ├── design.md                # Technical design (HOW)
│       └── executive.md             # Status tracking (WHERE)
└── tests/
    ├── test-busybox.sh              # Test harness
    └── README.md                    # Test harness documentation
```

### Key Files for Development

| Order | File | Purpose |
|-------|------|---------|
| 1 | `specs/proconly/requirements.md` | Read/write requirements FIRST |
| 2 | `specs/proconly/design.md` | Document technical approach |
| 3 | `tests/test-busybox.sh` | Write tests (verify they FAIL) |
| 4 | `proconly.sh` | Implement LAST |
| 5 | `specs/proconly/executive.md` | Update status when complete |

---

## Non-Goals

- Real-time monitoring (just snapshots)
- Pretty colors/formatting (may not render in all terminals)
- Interactive UI (keep it simple)
- Cross-platform support (Linux-only via `/proc`)
- Performance optimization (correctness over speed)

---

## Common Mistakes to Avoid

❌ Implementing a feature without a requirement in `specs/proconly/requirements.md`
❌ Writing code before the test exists and fails
❌ Skipping the design.md update
❌ Testing locally instead of in busybox container
❌ Forgetting to update executive.md status
❌ Using old requirement IDs (REQ-001) instead of new format (REQ-PO-001)

---

## 🔒 Pre-Implementation Checklist

Before writing ANY code, verify:

- [ ] Requirement exists in `specs/proconly/requirements.md` with REQ-PO-XXX ID
- [ ] Design approach documented in `specs/proconly/design.md`
- [ ] Test function exists in `tests/test-busybox.sh`
- [ ] Test FAILS before implementation (TDD)

**If any box is unchecked: DO NOT write code yet.**

---

## Reference

- **Methodology**: See `SPEARS.md` and `SPEARS_AGENT.md`
- **Current status**: See `specs/proconly/executive.md` (8 of 14 requirements complete)
- **Test harness docs**: See `tests/README.md`
