#!/bin/bash
# =============================================================================
# OpenClaw Security Audit - Channel Security Check
# =============================================================================
# Checks: DM policy, group policy, allowFrom wildcards, requireMention
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "Channel Security"

# ─── 1. DM Policy Check ─────────────────────────────────────────────────────

check_dm_policy() {
    echo -n "  DM policy: "

    if ! has_openclaw_config; then
        print_skip "Config not found"
        return
    fi

    local channels_cfg
    channels_cfg=$(read_config_value "channels" 2>/dev/null)

    if [ -z "$channels_cfg" ] || [ "$channels_cfg" = "{}" ]; then
        print_skip "No channels configured"
        return
    fi

    # Check for open DM policies
    python3 - "$OPENCLAW_CONFIG" <<'PYEOF'
import json, sys, re

def strip_comments(text):
    text = re.sub(r'//.*?$', '', text, flags=re.MULTILINE)
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    text = re.sub(r',\s*([}\]])', r'\1', text)
    return text

try:
    with open(sys.argv[1], 'r') as f:
        raw = f.read()
    cfg = json.loads(strip_comments(raw))
    channels = cfg.get("channels", {})

    open_channels = []
    safe_channels = []

    for name, ch_cfg in channels.items():
        if not isinstance(ch_cfg, dict):
            continue
        dm_policy = ch_cfg.get("dmPolicy", "pairing")
        if dm_policy == "open":
            open_channels.append(name)
        elif dm_policy in ("pairing", "allowlist", "disabled"):
            safe_channels.append(name)

    if open_channels:
        print(f"FAIL|DM policy is 'open' on: {', '.join(open_channels)}")
    elif safe_channels:
        print(f"PASS|All {len(safe_channels)} channel(s) have secure DM policy")
    else:
        print("SKIP|No channel DM policies found")
except Exception as e:
    print(f"SKIP|Could not parse config: {e}")
PYEOF
    local result
    result=$(python3 - "$OPENCLAW_CONFIG" <<'PYEOF'
import json, sys, re
def strip_comments(t):
    t = re.sub(r'//.*?$', '', t, flags=re.MULTILINE)
    t = re.sub(r'/\*.*?\*/', '', t, flags=re.DOTALL)
    t = re.sub(r',\s*([}\]])', r'\1', t)
    return t
try:
    with open(sys.argv[1]) as f: raw = f.read()
    cfg = json.loads(strip_comments(raw))
    channels = cfg.get("channels", {})
    open_ch = [n for n,c in channels.items() if isinstance(c,dict) and c.get("dmPolicy") == "open"]
    safe_ch = [n for n,c in channels.items() if isinstance(c,dict) and c.get("dmPolicy","pairing") in ("pairing","allowlist","disabled")]
    if open_ch: print(f"FAIL|{', '.join(open_ch)}")
    elif safe_ch: print(f"PASS|{len(safe_ch)}")
    else: print("SKIP|none")
except: print("SKIP|error")
PYEOF
    )

    local status="${result%%|*}"
    local detail="${result#*|}"

    case "$status" in
        FAIL) print_fail "DM policy is 'open' on: $detail" ;;
        PASS) print_pass "All $detail channel(s) have secure DM policy" ;;
        *) print_skip "Could not determine DM policies" ;;
    esac
}

# ─── 2. AllowFrom Wildcard Check ─────────────────────────────────────────────

check_allow_from() {
    echo -n "  AllowFrom wildcard: "

    if ! has_openclaw_config; then
        print_skip "Config not found"
        return
    fi

    # Search for allowFrom: ["*"] pattern
    local wildcard_found
    wildcard_found=$(grep -c '"allowFrom".*\[.*"\*"' "$OPENCLAW_CONFIG" 2>/dev/null || echo "0")

    if [ "$wildcard_found" -gt 0 ]; then
        print_fail "Found allowFrom: [\"*\"] - anyone can send messages"
    else
        print_pass "No wildcard allowFrom detected"
    fi
}

# ─── 3. Group Policy Check ───────────────────────────────────────────────────

check_group_policy() {
    echo -n "  Group policy: "

    if ! has_openclaw_config; then
        print_skip "Config not found"
        return
    fi

    local result
    result=$(python3 - "$OPENCLAW_CONFIG" <<'PYEOF'
import json, sys, re
def strip_comments(t):
    t = re.sub(r'//.*?$', '', t, flags=re.MULTILINE)
    t = re.sub(r'/\*.*?\*/', '', t, flags=re.DOTALL)
    t = re.sub(r',\s*([}\]])', r'\1', t)
    return t
try:
    with open(sys.argv[1]) as f: raw = f.read()
    cfg = json.loads(strip_comments(raw))
    channels = cfg.get("channels", {})
    open_groups = []
    for name, c in channels.items():
        if not isinstance(c, dict): continue
        gp = c.get("groupPolicy", "allowlist")
        if gp == "open":
            open_groups.append(name)
    if open_groups: print(f"WARN|{', '.join(open_groups)}")
    else: print("PASS|ok")
except: print("SKIP|error")
PYEOF
    )

    local status="${result%%|*}"
    local detail="${result#*|}"

    case "$status" in
        WARN) print_warn "Group policy is 'open' on: $detail" ;;
        PASS) print_pass "All group policies are restrictive" ;;
        *) print_skip "Could not determine group policies" ;;
    esac
}

# ─── 4. Require Mention Check ────────────────────────────────────────────────

check_require_mention() {
    echo -n "  Require mention in groups: "

    if ! has_openclaw_config; then
        print_skip "Config not found"
        return
    fi

    local result
    result=$(python3 - "$OPENCLAW_CONFIG" <<'PYEOF'
import json, sys, re
def strip_comments(t):
    t = re.sub(r'//.*?$', '', t, flags=re.MULTILINE)
    t = re.sub(r'/\*.*?\*/', '', t, flags=re.DOTALL)
    t = re.sub(r',\s*([}\]])', r'\1', t)
    return t
try:
    with open(sys.argv[1]) as f: raw = f.read()
    cfg = json.loads(strip_comments(raw))
    channels = cfg.get("channels", {})
    no_mention = []
    for name, c in channels.items():
        if not isinstance(c, dict): continue
        gp = c.get("groupPolicy", "allowlist")
        if gp != "disabled":
            rm = c.get("requireMention", False)
            if not rm:
                no_mention.append(name)
    if no_mention: print(f"WARN|{', '.join(no_mention)}")
    else: print("PASS|ok")
except: print("SKIP|error")
PYEOF
    )

    local status="${result%%|*}"
    local detail="${result#*|}"

    case "$status" in
        WARN) print_warn "requireMention not set on: $detail (bot responds to all messages in groups)" ;;
        PASS) print_pass "All group-enabled channels require @mention" ;;
        *) print_skip "Could not determine mention settings" ;;
    esac
}

# ─── Run All Checks ──────────────────────────────────────────────────────────

check_dm_policy
check_allow_from
check_group_policy
check_require_mention
