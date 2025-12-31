# proconly.sh

A copy-pasteable container debugger for minimal environments.

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

## Shell-Isms Of Note

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

---

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

---

### String Length

**Status:** `${#var}` works in dash, bash, and busybox ash. Safe to use.

```sh
cmd="hello"
echo ${#cmd}  # outputs "5" in all shells
```

---

### Printf Format Specifiers

**Status:** `printf "%.Ns"` (truncate to N chars) works in dash, bash, and
busybox ash. Safe to use.

```sh
printf "%.10s" "hello world"  # outputs "hello worl"
```

---

## Testing

```bash
# Run all requirement tests
./tests/test-busybox.sh req all

# Test specific requirement
./tests/test-busybox.sh req REQ-PO-001

# Quick manual test in busybox
./tests/test-busybox.sh run
```

## Requirements

See `specs/proconly/requirements.md` for full EARS-formatted requirements.

## License

MIT
