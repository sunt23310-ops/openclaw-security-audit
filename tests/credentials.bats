#!/usr/bin/env bats
# Credentials check tests

setup() {
    PROJECT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    source "$PROJECT_DIR/lib/common.sh"
}

# ── Syntax ─────────────────────────────────────────────────────

@test "credentials.sh has valid bash syntax" {
    bash -n "$PROJECT_DIR/checks/credentials.sh"
}

# ── File permissions ───────────────────────────────────────────

@test "get_file_permission returns 600 for restricted file" {
    local tmpfile=$(mktemp)
    chmod 600 "$tmpfile"
    result=$(get_file_permission "$tmpfile")
    [ "$result" = "600" ]
    rm -f "$tmpfile"
}

@test "get_file_permission returns 700 for restricted directory" {
    local tmpdir=$(mktemp -d)
    chmod 700 "$tmpdir"
    result=$(get_file_permission "$tmpdir")
    [ "$result" = "700" ]
    rmdir "$tmpdir"
}

@test "get_file_permission returns 644 for world-readable file" {
    local tmpfile=$(mktemp)
    chmod 644 "$tmpfile"
    result=$(get_file_permission "$tmpfile")
    [ "$result" = "644" ]
    rm -f "$tmpfile"
}

# ── Config detection ───────────────────────────────────────────

@test "has_openclaw_config returns false for missing config" {
    OPENCLAW_CONFIG="/nonexistent/openclaw.json"
    ! has_openclaw_config
}

@test "has_openclaw_config returns true for existing file" {
    local tmpfile=$(mktemp)
    OPENCLAW_CONFIG="$tmpfile"
    has_openclaw_config
    rm -f "$tmpfile"
}

# ── Plaintext key detection ────────────────────────────────────

@test "detects plaintext Anthropic API key" {
    local tmpfile=$(mktemp)
    echo '{"apiKey":"sk-ant-abc123def456ghi789"}' > "$tmpfile"
    result=$(grep -cE "sk-ant-|sk-proj-" "$tmpfile" || echo "0")
    [ "$result" -gt 0 ]
    rm -f "$tmpfile"
}

@test "detects plaintext OpenAI API key" {
    local tmpfile=$(mktemp)
    echo '{"apiKey":"sk-proj-abcdefghijk123456"}' > "$tmpfile"
    result=$(grep -cE "sk-ant-|sk-proj-" "$tmpfile" || echo "0")
    [ "$result" -gt 0 ]
    rm -f "$tmpfile"
}

@test "no false positive on SecretRef config" {
    local tmpfile=$(mktemp)
    echo '{"apiKey":{"source":"env","id":"ANTHROPIC_API_KEY"}}' > "$tmpfile"
    ! grep -qE "sk-ant-|sk-proj-" "$tmpfile"
    rm -f "$tmpfile"
}

# ── Counter functions ──────────────────────────────────────────

@test "counter functions increment correctly" {
    reset_counters
    print_pass "a" > /dev/null
    print_pass "b" > /dev/null
    print_warn "c" > /dev/null
    print_fail "d" > /dev/null
    print_skip "e" > /dev/null
    [ "$PASS_COUNT" -eq 2 ]
    [ "$WARN_COUNT" -eq 1 ]
    [ "$FAIL_COUNT" -eq 1 ]
    [ "$SKIP_COUNT" -eq 1 ]
}

@test "reset_counters zeroes all counters" {
    PASS_COUNT=5; WARN_COUNT=3; FAIL_COUNT=2; SKIP_COUNT=1
    reset_counters
    [ "$PASS_COUNT" -eq 0 ]
    [ "$WARN_COUNT" -eq 0 ]
    [ "$FAIL_COUNT" -eq 0 ]
    [ "$SKIP_COUNT" -eq 0 ]
}
