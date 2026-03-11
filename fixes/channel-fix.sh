#!/bin/bash
# =============================================================================
# OpenClaw Security Audit - Channel Policy Fix
# =============================================================================
# Fixes: DM policy, allowFrom wildcards, group policy
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "Channel Policy Fix"

if ! has_openclaw_config; then
    print_fail "OpenClaw config not found at $OPENCLAW_CONFIG"
    exit 1
fi

# ─── 1. Fix Open DM Policies ─────────────────────────────────────────────────

fix_dm_policy() {
    echo -e "${BOLD}1. Fix Open DM Policies${NC}"
    echo "   Changes all 'open' DM policies to 'pairing' (requires code to connect)."
    echo ""

    local open_channels
    open_channels=$(python3 - "$OPENCLAW_CONFIG" "$LIB_DIR" <<'PYEOF'
import sys
sys.path.insert(0, sys.argv[2])
from json5_parser import load_config
try:
    cfg = load_config(sys.argv[1])
    channels = cfg.get("channels", {})
    open_ch = [n for n,c in channels.items() if isinstance(c,dict) and c.get("dmPolicy") == "open"]
    print(','.join(open_ch) if open_ch else "")
except: print("")
PYEOF
    )

    if [ -z "$open_channels" ]; then
        print_pass "No open DM policies found"
        echo ""
        return
    fi

    echo "   Found open DM policies on: $open_channels"

    if ! confirm_action "   Change these to 'pairing' mode?"; then
        echo "   Skipped."
        echo ""
        return
    fi

    python3 - "$OPENCLAW_CONFIG" "$LIB_DIR" <<'PYEOF'
import json, sys
sys.path.insert(0, sys.argv[2])
from json5_parser import load_config

cfg = load_config(sys.argv[1])

changed = 0
for name, ch_cfg in cfg.get("channels", {}).items():
    if isinstance(ch_cfg, dict) and ch_cfg.get("dmPolicy") == "open":
        ch_cfg["dmPolicy"] = "pairing"
        changed += 1

with open(sys.argv[1], 'w') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print(changed)
PYEOF

    print_pass "Fixed DM policies to 'pairing' mode"
    echo ""
}

# ─── 2. Fix AllowFrom Wildcards ──────────────────────────────────────────────

fix_allow_from() {
    echo -e "${BOLD}2. Fix AllowFrom Wildcards${NC}"
    echo "   Removes dangerous [\"*\"] allowFrom entries."
    echo ""

    local has_wildcard
    has_wildcard=$(grep -c '"allowFrom".*\[.*"\*"' "$OPENCLAW_CONFIG" 2>/dev/null || echo "0")

    if [ "$has_wildcard" -eq 0 ]; then
        print_pass "No wildcard allowFrom found"
        echo ""
        return
    fi

    echo "   Found $has_wildcard channel(s) with allowFrom: [\"*\"]"
    echo -e "   ${YELLOW}Warning: This will remove the wildcard. You'll need to add specific contacts.${NC}"

    if ! confirm_action "   Remove wildcard allowFrom?"; then
        echo "   Skipped."
        echo ""
        return
    fi

    python3 - "$OPENCLAW_CONFIG" "$LIB_DIR" <<'PYEOF'
import json, sys
sys.path.insert(0, sys.argv[2])
from json5_parser import load_config

cfg = load_config(sys.argv[1])

changed = 0
for name, ch_cfg in cfg.get("channels", {}).items():
    if isinstance(ch_cfg, dict):
        af = ch_cfg.get("allowFrom", [])
        if isinstance(af, list) and "*" in af:
            ch_cfg["allowFrom"] = []
            changed += 1

with open(sys.argv[1], 'w') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print(changed)
PYEOF

    print_pass "Removed wildcard allowFrom entries"
    echo -e "   ${YELLOW}Remember to add specific contacts via: openclaw config set channels.<name>.allowFrom${NC}"
    echo ""
}

# ─── 3. Enable requireMention ────────────────────────────────────────────────

fix_require_mention() {
    echo -e "${BOLD}3. Enable requireMention for Groups${NC}"
    echo "   Requires @mention for the bot to respond in group chats."
    echo ""

    if ! confirm_action "   Enable requireMention on all group-enabled channels?"; then
        echo "   Skipped."
        echo ""
        return
    fi

    python3 - "$OPENCLAW_CONFIG" "$LIB_DIR" <<'PYEOF'
import json, sys
sys.path.insert(0, sys.argv[2])
from json5_parser import load_config

cfg = load_config(sys.argv[1])

changed = 0
for name, ch_cfg in cfg.get("channels", {}).items():
    if isinstance(ch_cfg, dict):
        gp = ch_cfg.get("groupPolicy", "allowlist")
        if gp != "disabled" and not ch_cfg.get("requireMention", False):
            ch_cfg["requireMention"] = True
            changed += 1

with open(sys.argv[1], 'w') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print(changed)
PYEOF

    print_pass "Enabled requireMention on group-enabled channels"
    echo ""
}

# ─── Run Fixes ────────────────────────────────────────────────────────────────

fix_dm_policy
fix_allow_from
fix_require_mention
