# Testing Harness for proconly.sh

This directory contains the testing infrastructure for `proconly.sh`. The goal is to rapidly test the script in a real busybox environment that mimics production containers.

## Testing Methodology: EARS → Tests → Code

This project follows the **EARS → Tests → Code** development methodology:

1. **EARS** (Easy Approach to Requirements Syntax) - Requirements written in structured natural language
2. **Tests** - Automated tests that validate each requirement
3. **Code** - Implementation that passes the tests

### What is EARS?

EARS is a structured way to write requirements that are clear, testable, and unambiguous. It uses five patterns:

- **Ubiquitous**: The system shall [requirement]
- **Event-driven**: WHEN [trigger], the system shall [requirement]
- **State-driven**: WHILE [state], the system shall [requirement]
- **Optional feature**: WHERE [feature], the system shall [requirement]
- **Unwanted behavior**: IF [condition], THEN the system shall [requirement]

All requirements are documented in `tests/requirements.md` with unique IDs (e.g., REQ-001).

## Prerequisites

- Docker installed and running
- Bash shell (for running test scripts)

## Quick Start

### Primary Mode: Requirement Testing
```bash
# Run all requirement tests (use this most often)
./tests/test-busybox.sh req all

# Test a specific requirement
./tests/test-busybox.sh req REQ-001
./tests/test-busybox.sh req REQ-002
```

### Quick Manual Testing
```bash
# Just execute the script and see output
./tests/test-busybox.sh run
```

That's it! Only two modes: `req` for TDD workflow, `run` for quick checks.

## Test Modes

The test harness has been simplified to only two modes:

### `req` - Requirement Testing (Primary Mode)

This is the **primary testing mode** - use this for TDD workflow.

Test individual requirements:
```bash
./tests/test-busybox.sh req REQ-001  # Script execution
./tests/test-busybox.sh req REQ-002  # Process discovery
./tests/test-busybox.sh req REQ-003  # Process information display
./tests/test-busybox.sh req REQ-004  # Command line parsing
./tests/test-busybox.sh req REQ-005  # Process state detection
```

Run all requirement tests:
```bash
./tests/test-busybox.sh req all
```

**Use this for**:
- TDD workflow (requirement → test → code)
- Verifying specific functionality works
- Pre-commit checks
- Tracking implementation progress

**Why this mode?**
- Each test validates specific criteria from requirements.md
- Self-contained: creates its own test environments
- Clear pass/fail with detailed output
- Maps 1:1 to EARS requirements

### `run` - Quick Manual Execution

Pipes the script into a busybox container and shows output.

```bash
./tests/test-busybox.sh run
```

**Use this for**:
- Quick manual checks during coding
- Seeing raw script output
- Testing the "copy-paste into terminal" workflow
- Rapid iteration when debugging

**Why this mode?**
- Fast and simple
- Shows actual output users will see
- Validates copy-paste deliverability (REQ-031)

## Development Workflow

### EARS → Tests → Code (Recommended)

The primary development workflow follows TDD principles with EARS:

1. **Write/Review Requirement** in `tests/requirements.md`
   - Use EARS syntax (Ubiquitous, Event-driven, State-driven, etc.)
   - Assign a unique ID (e.g., REQ-010)
   - Define clear test criteria

2. **Write Test** in `tests/test-busybox.sh`
   - Create a `test_req_XXX()` function
   - Implement checks based on test criteria
   - Add to `test_all_requirements()` array

3. **Run Test** (should fail initially)
   ```bash
   ./tests/test-busybox.sh req REQ-XXX
   ```

4. **Write Code** in `proconly.sh`
   - Implement the feature
   - Follow busybox/POSIX sh constraints

5. **Run Test Again** (should pass)
   ```bash
   ./tests/test-busybox.sh req REQ-XXX
   ```

6. **Run All Tests** to ensure no regressions
   ```bash
   ./tests/test-busybox.sh req all
   ```

### Quick Iteration Workflow

For rapid development and debugging:

1. **Edit** `proconly.sh`
2. **Test** with `./tests/test-busybox.sh req all`
3. **Quick check** with `./tests/test-busybox.sh run` if needed

```bash
# One-liner: edit then test
vim proconly.sh && ./tests/test-busybox.sh req all
```

## Troubleshooting

**Docker not found**
- Install Docker: https://docs.docker.com/get-docker/

**Permission denied**
- Make script executable: `chmod +x tests/test-busybox.sh`

**Script fails in busybox but works locally**
- You may be using bash-specific syntax
- Use `docker run -it busybox sh` to debug manually
- Remember: busybox has limited awk, sed, and only POSIX sh

**Can't see container output**
- Check if Docker is running: `docker ps`
- Try running container manually: `docker run --rm -it busybox sh`

## File Structure

```
tests/
├── README.md           # This file - test harness documentation
├── requirements.md     # EARS requirements with unique IDs
└── test-busybox.sh     # Main test harness script
```

### Key Files

- **requirements.md**: EARS-formatted requirements with test criteria
  - Each requirement has a unique ID (REQ-001, REQ-002, etc.)
  - Maps requirements to test functions
  - Tracks implementation status

- **test-busybox.sh**: Test execution engine (293 lines, simplified)
  - Requirement-based tests (`test_req_XXX` functions)
  - Quick execution mode for manual testing
  - Only two modes: `req` and `run`

## Tips

### For Development
- **Start with requirements**: Always write/update requirements.md before coding
- **Run tests frequently**: Use `./tests/test-busybox.sh req all` after each change
- **Test individual requirements**: Use `req REQ-XXX` to focus on specific features
- **Watch test output**: Requirement tests show exactly what passed/failed

### For Testing
- **Test in busybox**: If it doesn't work in busybox, it won't work in prod
- **Self-contained tests**: Each requirement test creates its own environment
- **Update status**: Keep requirements.md status table current
- **Use run mode**: Quick `run` checks to see actual output

### EARS Best Practices
- Write requirements BEFORE tests
- Write tests BEFORE code
- Keep requirements atomic (one clear thing per requirement)
- Map requirements to test functions 1:1 (test_req_XXX)
- Update requirements.md status table as you implement
