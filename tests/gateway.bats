#!/usr/bin/env bats
# Gateway check tests

setup() {
    PROJECT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    source "$PROJECT_DIR/lib/common.sh"
}

# ── Constants ──────────────────────────────────────────────────

@test "OPENCLAW_GATEWAY_PORT is 18789" {
    [ "$OPENCLAW_GATEWAY_PORT" = "18789" ]
}

@test "OPENCLAW_ALL_PORTS contains expected ports" {
    [[ " ${OPENCLAW_ALL_PORTS[*]} " == *" 18789 "* ]]
    [[ " ${OPENCLAW_ALL_PORTS[*]} " == *" 18790 "* ]]
    [[ " ${OPENCLAW_ALL_PORTS[*]} " == *" 18791 "* ]]
    [[ " ${OPENCLAW_ALL_PORTS[*]} " == *" 18793 "* ]]
}

@test "gateway.sh has valid bash syntax" {
    bash -n "$PROJECT_DIR/checks/gateway.sh"
}

# ── read_config_value via json5_parser.py ──────────────────────

@test "read_config_value returns empty for missing file" {
    OPENCLAW_CONFIG="/nonexistent/path.json"
    result=$(read_config_value "gateway.port")
    [ -z "$result" ]
}

@test "read_config_value parses JSON correctly (via json5_parser.py)" {
    # Override to force python path, not openclaw CLI
    has_openclaw_cli() { return 1; }

    local tmpfile=$(mktemp)
    echo '{"gateway": {"port": 18789, "auth": {"mode": "token"}}}' > "$tmpfile"
    OPENCLAW_CONFIG="$tmpfile"

    result=$(read_config_value "gateway.port")
    [ "$result" = "18789" ]

    result=$(read_config_value "gateway.auth.mode")
    [ "$result" = "token" ]
    rm -f "$tmpfile"
}

@test "read_config_value handles JSON5 comments (via json5_parser.py)" {
    has_openclaw_cli() { return 1; }

    local tmpfile=$(mktemp)
    cat > "$tmpfile" <<'EOF'
{
    // This is a comment
    "gateway": {
        "port": 18789
    }
}
EOF
    OPENCLAW_CONFIG="$tmpfile"
    result=$(read_config_value "gateway.port")
    [ "$result" = "18789" ]
    rm -f "$tmpfile"
}

# ── Structured output ─────────────────────────────────────────

@test "print_pass emits structured output when STRUCTURED_OUTPUT_FILE is set" {
    local tmpfile=$(mktemp)
    STRUCTURED_OUTPUT_FILE="$tmpfile"
    print_pass "Gateway bound to localhost" > /dev/null
    local content=$(cat "$tmpfile")
    [[ "$content" == *"pass|Gateway bound to localhost"* ]]
    rm -f "$tmpfile"
}

@test "print_fail emits structured output" {
    local tmpfile=$(mktemp)
    STRUCTURED_OUTPUT_FILE="$tmpfile"
    print_fail "Gateway exposed" > /dev/null
    local content=$(cat "$tmpfile")
    [[ "$content" == *"fail|Gateway exposed"* ]]
    rm -f "$tmpfile"
}

@test "structured output not written when STRUCTURED_OUTPUT_FILE is empty" {
    STRUCTURED_OUTPUT_FILE=""
    reset_counters
    print_pass "test" > /dev/null
    # Should not crash, counter should increment
    [ "$PASS_COUNT" -eq 1 ]
}

# ── Port helpers ───────────────────────────────────────────────

@test "get_port_listeners returns empty for unused port" {
    # Port 19999 should not be in use
    result=$(get_port_listeners 19999)
    [ -z "$result" ]
}

@test "is_port_public returns false for unused port" {
    ! is_port_public 19999
}
