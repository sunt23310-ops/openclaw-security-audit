#!/bin/bash
# =============================================================================
# OpenClaw Security Audit - Gateway Fix
# =============================================================================
# Fixes: bind to localhost, generate strong token
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "Gateway Security Fix"

# ─── 1. Fix Gateway Binding ──────────────────────────────────────────────────

fix_gateway_binding() {
    echo -e "${BOLD}1. Fix Gateway Binding${NC}"
    echo "   Current gateway may be bound to 0.0.0.0 (all interfaces)."
    echo "   This fix will bind it to 127.0.0.1 (localhost only)."
    echo ""

    if ! confirm_action "   Apply fix: bind gateway to localhost?"; then
        echo "   Skipped."
        return
    fi

    if has_openclaw_cli; then
        openclaw config set gateway.bind "127.0.0.1" 2>/dev/null
        print_pass "Gateway bind set to 127.0.0.1 via openclaw CLI"
    elif has_openclaw_config; then
        # Manual JSON update
        python3 - "$OPENCLAW_CONFIG" <<'PYEOF'
import json, sys, re

config_path = sys.argv[1]

def strip_comments(t):
    t = re.sub(r'//.*?$', '', t, flags=re.MULTILINE)
    t = re.sub(r'/\*.*?\*/', '', t, flags=re.DOTALL)
    t = re.sub(r',\s*([}\]])', r'\1', t)
    return t

with open(config_path, 'r') as f:
    raw = f.read()

cfg = json.loads(strip_comments(raw))
if "gateway" not in cfg:
    cfg["gateway"] = {}
cfg["gateway"]["bind"] = "127.0.0.1"

with open(config_path, 'w') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print("Done")
PYEOF
        print_pass "Gateway bind set to 127.0.0.1 in config file"
    else
        print_fail "No OpenClaw CLI or config found"
    fi

    echo ""
    echo -e "   ${YELLOW}Note: Restart OpenClaw gateway for changes to take effect.${NC}"
    echo ""
}

# ─── 2. Generate Strong Token ────────────────────────────────────────────────

fix_gateway_token() {
    echo -e "${BOLD}2. Generate Strong Gateway Token${NC}"
    echo "   Generates a cryptographically strong 64-character token."
    echo ""

    if ! confirm_action "   Generate and set new gateway token?"; then
        echo "   Skipped."
        return
    fi

    local new_token
    new_token=$(openssl rand -hex 32)

    if has_openclaw_cli; then
        openclaw config set gateway.auth.mode "token" 2>/dev/null
        openclaw config set gateway.auth.token "$new_token" 2>/dev/null
        print_pass "New token set via openclaw CLI"
    elif has_openclaw_config; then
        python3 - "$OPENCLAW_CONFIG" "$new_token" <<'PYEOF'
import json, sys, re

config_path = sys.argv[1]
new_token = sys.argv[2]

def strip_comments(t):
    t = re.sub(r'//.*?$', '', t, flags=re.MULTILINE)
    t = re.sub(r'/\*.*?\*/', '', t, flags=re.DOTALL)
    t = re.sub(r',\s*([}\]])', r'\1', t)
    return t

with open(config_path, 'r') as f:
    raw = f.read()

cfg = json.loads(strip_comments(raw))
if "gateway" not in cfg:
    cfg["gateway"] = {}
if "auth" not in cfg["gateway"]:
    cfg["gateway"]["auth"] = {}
cfg["gateway"]["auth"]["mode"] = "token"
cfg["gateway"]["auth"]["token"] = new_token

with open(config_path, 'w') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print("Done")
PYEOF
        print_pass "New token written to config file"
    else
        print_fail "No OpenClaw CLI or config found"
        return
    fi

    echo ""
    echo -e "   ${CYAN}New token: ${new_token}${NC}"
    echo -e "   ${YELLOW}Save this token - you'll need it to connect clients.${NC}"
    echo -e "   ${YELLOW}Restart OpenClaw gateway for changes to take effect.${NC}"
    echo ""
}

# ─── Run Fixes ────────────────────────────────────────────────────────────────

fix_gateway_binding
fix_gateway_token
