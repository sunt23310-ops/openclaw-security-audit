#!/usr/bin/env bats
# Credentials check tests

setup() {
    PROJECT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    source "$PROJECT_DIR/lib/common.sh"
}

@test "credentials.sh has valid bash syntax" {
    bash -n "$PROJECT_DIR/checks/credentials.sh"
}

@test "get_file_permission returns correct value" {
    local tmpfile
    tmpfile=$(mktemp)
    chmod 600 "$tmpfile"
    result=$(get_file_permission "$tmpfile")
    [ "$result" = "600" ]
    rm -f "$tmpfile"
}

@test "get_file_permission returns correct for directory" {
    local tmpdir
    tmpdir=$(mktemp -d)
    chmod 700 "$tmpdir"
    result=$(get_file_permission "$tmpdir")
    [ "$result" = "700" ]
    rmdir "$tmpdir"
}

@test "has_openclaw_config returns false for missing config" {
    OPENCLAW_CONFIG="/nonexistent/openclaw.json"
    ! has_openclaw_config
}

@test "detects plaintext API keys in config" {
    local tmpfile
    tmpfile=$(mktemp)
    echo '{"models":{"providers":{"anthropic":{"apiKey":"sk-ant-abc123def456"}}}}' > "$tmpfile"
    result=$(grep -cE "sk-ant-|sk-proj-" "$tmpfile" || echo "0")
    [ "$result" -gt 0 ]
    rm -f "$tmpfile"
}

@test "no false positive on clean config" {
    local tmpfile
    tmpfile=$(mktemp)
    echo '{"models":{"providers":{"anthropic":{"apiKey":{"source":"env","id":"ANTHROPIC_API_KEY"}}}}}' > "$tmpfile"
    result=$(grep -cE "sk-ant-|sk-proj-" "$tmpfile" || echo "0")
    [ "$result" -eq 0 ]
    rm -f "$tmpfile"
}
