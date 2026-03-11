#!/bin/bash
# =============================================================================
# OpenClaw Security Audit - Common Library
# =============================================================================
# Shared utilities: colors, logging, config reading, counters
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# OpenClaw paths
OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"
OPENCLAW_CONFIG="${OPENCLAW_CONFIG_PATH:-$OPENCLAW_STATE_DIR/openclaw.json}"
OPENCLAW_ENV_FILE="$OPENCLAW_STATE_DIR/.env"
OPENCLAW_WORKSPACE="$OPENCLAW_STATE_DIR/workspace"
OPENCLAW_AGENTS_DIR="$OPENCLAW_STATE_DIR/agents"
OPENCLAW_CREDENTIALS_DIR="$OPENCLAW_STATE_DIR/credentials"

# OpenClaw ports
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_BRIDGE_PORT=18790
OPENCLAW_BROWSER_PORT=18791
OPENCLAW_CANVAS_PORT=18793
OPENCLAW_CDP_PORT_MIN=18800
OPENCLAW_CDP_PORT_MAX=18899
OPENCLAW_OAUTH_PORT=1455
OPENCLAW_ALL_PORTS=(18789 18790 18791 18793)

# Result counters
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Structured output mode: when set to a file path, results are also
# written as machine-readable lines (STATUS|detail) for report generation.
# This avoids fragile grep-based parsing of colored terminal output.
STRUCTURED_OUTPUT_FILE="${STRUCTURED_OUTPUT_FILE:-}"

_emit_structured() {
    local status="$1"
    local detail="$2"
    if [ -n "$STRUCTURED_OUTPUT_FILE" ]; then
        echo "${status}|${detail}" >> "$STRUCTURED_OUTPUT_FILE"
    fi
}

# =============================================================================
# Logging Functions
# =============================================================================

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS_COUNT=$((PASS_COUNT + 1))
    _emit_structured "pass" "$1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARN_COUNT=$((WARN_COUNT + 1))
    _emit_structured "warn" "$1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    _emit_structured "fail" "$1"
}

print_skip() {
    echo -e "${BLUE}[SKIP]${NC} $1"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    _emit_structured "skip" "$1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}=== $1 ===${NC}"
    echo ""
}

print_summary() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Summary:${NC} ${GREEN}${PASS_COUNT} passed${NC} | ${YELLOW}${WARN_COUNT} warnings${NC} | ${RED}${FAIL_COUNT} failed${NC} | ${BLUE}${SKIP_COUNT} skipped${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

reset_counters() {
    PASS_COUNT=0
    WARN_COUNT=0
    FAIL_COUNT=0
    SKIP_COUNT=0
}

# =============================================================================
# Config Reading (Safe - no string interpolation)
# =============================================================================

# Read a value from OpenClaw JSON config using dot notation
# Usage: read_config_value "gateway.port"
read_config_value() {
    local key="$1"
    if [ ! -f "$OPENCLAW_CONFIG" ]; then
        echo ""
        return 0
    fi

    # Prefer openclaw CLI if available (handles JSON5 + $include natively)
    if has_openclaw_cli; then
        openclaw config get "$key" 2>/dev/null || true
        return
    fi

    # Use the shared json5_parser.py (single source of truth)
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    python3 "$lib_dir/json5_parser.py" "$OPENCLAW_CONFIG" "$key" 2>/dev/null || true
}

# Check if OpenClaw config exists
has_openclaw_config() {
    [ -f "$OPENCLAW_CONFIG" ]
}

# Check if OpenClaw is installed
has_openclaw_cli() {
    command -v openclaw &>/dev/null
}

# Check if OpenClaw gateway is running
is_gateway_running() {
    if command -v lsof &>/dev/null; then
        lsof -i ":${OPENCLAW_GATEWAY_PORT}" -sTCP:LISTEN &>/dev/null 2>&1
    elif command -v ss &>/dev/null; then
        ss -tlnp "sport = :${OPENCLAW_GATEWAY_PORT}" 2>/dev/null | grep -q LISTEN
    elif [ -f /proc/net/tcp ]; then
        # Fallback: check /proc/net/tcp (port in hex)
        local hex_port
        hex_port=$(printf "%04X" "$OPENCLAW_GATEWAY_PORT")
        grep -qi ":${hex_port}" /proc/net/tcp 2>/dev/null
    else
        return 1
    fi
}

# Get file permission in octal
get_file_permission() {
    local file="$1"
    if [ -f "$file" ] || [ -d "$file" ]; then
        stat -f "%Lp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null
    fi
}

# Get TCP listeners on a given port (cross-platform: lsof or ss)
get_port_listeners() {
    local port="$1"
    if command -v lsof &>/dev/null; then
        lsof -i ":${port}" -sTCP:LISTEN 2>/dev/null || true
    elif command -v ss &>/dev/null; then
        ss -tlnp "sport = :${port}" 2>/dev/null | tail -n +2 || true
    fi
}

# Check if a port is bound to a public (non-loopback) interface
is_port_public() {
    local port="$1"
    local listeners
    listeners=$(get_port_listeners "$port")
    [ -z "$listeners" ] && return 1
    echo "$listeners" | grep -q "\*:${port}\|0\.0\.0\.0:\|:::${port}\|0\.0\.0\.0:${port}"
}

# Confirm action with user
confirm_action() {
    local prompt="$1"
    echo -n -e "${YELLOW}$prompt [y/N]: ${NC}"
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# Get project root directory
get_project_root() {
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}
