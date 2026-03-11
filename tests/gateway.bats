#!/usr/bin/env bats
# Gateway check tests

setup() {
    PROJECT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    source "$PROJECT_DIR/lib/common.sh"
}

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

@test "read_config_value returns empty for missing file" {
    OPENCLAW_CONFIG="/nonexistent/path.json"
    result=$(read_config_value "gateway.port")
    [ -z "$result" ]
}

@test "read_config_value parses JSON correctly" {
    local tmpfile
    tmpfile=$(mktemp)
    echo '{"gateway": {"port": 18789, "auth": {"mode": "token"}}}' > "$tmpfile"
    OPENCLAW_CONFIG="$tmpfile"

    result=$(read_config_value "gateway.port")
    [ "$result" = "18789" ]

    result=$(read_config_value "gateway.auth.mode")
    [ "$result" = "token" ]

    rm -f "$tmpfile"
}

@test "read_config_value handles JSON5 comments" {
    local tmpfile
    tmpfile=$(mktemp)
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
