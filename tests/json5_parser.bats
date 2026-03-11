#!/usr/bin/env bats
# JSON5 parser tests — covers the single source of truth parser

setup() {
    PROJECT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    PARSER="$PROJECT_DIR/lib/json5_parser.py"
}

# ── Standard JSON ──────────────────────────────────────────────

@test "parses standard JSON" {
    local tmpfile=$(mktemp)
    echo '{"gateway": {"port": 18789}}' > "$tmpfile"
    result=$(python3 "$PARSER" "$tmpfile" "gateway.port")
    [ "$result" = "18789" ]
    rm -f "$tmpfile"
}

@test "parses nested keys" {
    local tmpfile=$(mktemp)
    echo '{"gateway": {"auth": {"mode": "token"}}}' > "$tmpfile"
    result=$(python3 "$PARSER" "$tmpfile" "gateway.auth.mode")
    [ "$result" = "token" ]
    rm -f "$tmpfile"
}

@test "returns JSON for dict values" {
    local tmpfile=$(mktemp)
    echo '{"gateway": {"auth": {"mode": "token"}}}' > "$tmpfile"
    result=$(python3 "$PARSER" "$tmpfile" "gateway.auth")
    echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['mode']=='token'"
    rm -f "$tmpfile"
}

@test "returns empty for missing key" {
    local tmpfile=$(mktemp)
    echo '{"gateway": {}}' > "$tmpfile"
    result=$(python3 "$PARSER" "$tmpfile" "gateway.auth.mode")
    [ -z "$result" ]
    rm -f "$tmpfile"
}

# ── JSON5: Comments ────────────────────────────────────────────

@test "handles line comments" {
    local tmpfile=$(mktemp)
    cat > "$tmpfile" <<'EOF'
{
    // This is a comment
    "port": 18789
}
EOF
    result=$(python3 "$PARSER" "$tmpfile" "port")
    [ "$result" = "18789" ]
    rm -f "$tmpfile"
}

@test "handles block comments" {
    local tmpfile=$(mktemp)
    cat > "$tmpfile" <<'EOF'
{
    /* block comment */
    "port": 18789
}
EOF
    result=$(python3 "$PARSER" "$tmpfile" "port")
    [ "$result" = "18789" ]
    rm -f "$tmpfile"
}

@test "does not strip // inside strings (URL safety)" {
    local tmpfile=$(mktemp)
    cat > "$tmpfile" <<'EOF'
{
    "url": "https://example.com/path",
    "port": 443
}
EOF
    result=$(python3 "$PARSER" "$tmpfile" "url")
    [ "$result" = "https://example.com/path" ]
    rm -f "$tmpfile"
}

# ── JSON5: Trailing commas ─────────────────────────────────────

@test "handles trailing commas" {
    local tmpfile=$(mktemp)
    cat > "$tmpfile" <<'EOF'
{
    "a": 1,
    "b": 2,
}
EOF
    result=$(python3 "$PARSER" "$tmpfile" "b")
    [ "$result" = "2" ]
    rm -f "$tmpfile"
}

@test "handles trailing commas in arrays" {
    local tmpfile=$(mktemp)
    cat > "$tmpfile" <<'EOF'
{
    "items": ["a", "b",]
}
EOF
    result=$(python3 "$PARSER" "$tmpfile" "items")
    echo "$result" | python3 -c "import json,sys; assert json.load(sys.stdin)==['a','b']"
    rm -f "$tmpfile"
}

# ── JSON5: Unquoted keys ──────────────────────────────────────

@test "handles unquoted keys" {
    local tmpfile=$(mktemp)
    cat > "$tmpfile" <<'EOF'
{
    port: 18789,
    bind: "127.0.0.1"
}
EOF
    result=$(python3 "$PARSER" "$tmpfile" "port")
    [ "$result" = "18789" ]
    result2=$(python3 "$PARSER" "$tmpfile" "bind")
    [ "$result2" = "127.0.0.1" ]
    rm -f "$tmpfile"
}

# ── JSON5: Real-world OpenClaw config ──────────────────────────

@test "parses realistic OpenClaw config" {
    local tmpfile=$(mktemp)
    cat > "$tmpfile" <<'EOF'
{
    // OpenClaw config
    agents: {
        defaults: {
            workspace: "~/.openclaw/workspace",
        },
    },
    channels: {
        whatsapp: {
            allowFrom: ["+15555550123"],
            dmPolicy: "pairing",
        },
        telegram: {
            dmPolicy: "open",  // INSECURE!
            requireMention: false,
        },
    },
    gateway: {
        port: 18789,
        auth: {
            mode: "token",
        },
    },
    /* Model configuration */
    models: {
        defaults: {
            primary: "anthropic/claude-opus-4-6",
        },
    },
}
EOF
    [ "$(python3 "$PARSER" "$tmpfile" "gateway.port")" = "18789" ]
    [ "$(python3 "$PARSER" "$tmpfile" "gateway.auth.mode")" = "token" ]
    [ "$(python3 "$PARSER" "$tmpfile" "channels.telegram.dmPolicy")" = "open" ]
    [ "$(python3 "$PARSER" "$tmpfile" "models.defaults.primary")" = "anthropic/claude-opus-4-6" ]
    rm -f "$tmpfile"
}

# ── Error handling ─────────────────────────────────────────────

@test "handles missing file gracefully" {
    result=$(python3 "$PARSER" "/nonexistent/file.json" "key" 2>/dev/null || true)
    [ -z "$result" ]
}

@test "handles invalid JSON gracefully" {
    local tmpfile=$(mktemp)
    echo "not json at all" > "$tmpfile"
    result=$(python3 "$PARSER" "$tmpfile" "key" 2>/dev/null || true)
    [ -z "$result" ]
    rm -f "$tmpfile"
}
