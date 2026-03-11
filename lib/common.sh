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

# =============================================================================
# Logging Functions
# =============================================================================

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

print_skip() {
    echo -e "${BLUE}[SKIP]${NC} $1"
    SKIP_COUNT=$((SKIP_COUNT + 1))
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
        return 1
    fi
    python3 - "$OPENCLAW_CONFIG" "$key" 2>/dev/null <<'PYEOF'
import json, sys, re

config_path = sys.argv[1]
key_path = sys.argv[2]

# Strip JSON5 comments for compatibility
def strip_comments(text):
    text = re.sub(r'//.*?$', '', text, flags=re.MULTILINE)
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    # Remove trailing commas before } or ]
    text = re.sub(r',\s*([}\]])', r'\1', text)
    return text

try:
    with open(config_path, 'r') as f:
        raw = f.read()
    cleaned = strip_comments(raw)
    cfg = json.loads(cleaned)
    keys = key_path.split('.')
    val = cfg
    for k in keys:
        if isinstance(val, dict):
            val = val.get(k)
        else:
            val = None
            break
    if val is not None:
        if isinstance(val, (dict, list)):
            print(json.dumps(val))
        else:
            print(val)
except Exception:
    pass
PYEOF
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
    lsof -i ":${OPENCLAW_GATEWAY_PORT}" -sTCP:LISTEN &>/dev/null 2>&1
}

# Get file permission in octal
get_file_permission() {
    local file="$1"
    if [ -f "$file" ] || [ -d "$file" ]; then
        stat -f "%Lp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null
    fi
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
