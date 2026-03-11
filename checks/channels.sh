#!/bin/bash
# =============================================================================
# OpenClaw Security Audit - Channel Security Check
# =============================================================================
# Checks: DM policy, group policy, allowFrom wildcards, requireMention
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

LIB_DIR="$SCRIPT_DIR/../lib"

print_header "Channel Security"

# Helper: run a channel check via the shared JSON5 parser
_channel_check() {
    local check_type="$1"
    python3 - "$OPENCLAW_CONFIG" "$check_type" "$LIB_DIR" <<'PYEOF'
import sys, os
sys.path.insert(0, sys.argv[3])
from json5_parser import load_config

check_type = sys.argv[2]

try:
    cfg = load_config(sys.argv[1])
    channels = cfg.get("channels", {})

    if check_type == "dm_policy":
        open_ch = [n for n,c in channels.items() if isinstance(c,dict) and c.get("dmPolicy") == "open"]
        safe_ch = [n for n,c in channels.items() if isinstance(c,dict) and c.get("dmPolicy","pairing") in ("pairing","allowlist","disabled")]
        if open_ch: print(f"FAIL|{', '.join(open_ch)}")
        elif safe_ch: print(f"PASS|{len(safe_ch)}")
        else: print("SKIP|none")

    elif check_type == "allow_from":
        wildcard_ch = []
        for name, c in channels.items():
            if isinstance(c, dict):
                af = c.get("allowFrom", [])
                if isinstance(af, list) and "*" in af:
                    wildcard_ch.append(name)
        if wildcard_ch: print(f"FAIL|{', '.join(wildcard_ch)}")
        else: print("PASS|ok")

    elif check_type == "group_policy":
        open_groups = [n for n,c in channels.items() if isinstance(c,dict) and c.get("groupPolicy","allowlist") == "open"]
        if open_groups: print(f"WARN|{', '.join(open_groups)}")
        else: print("PASS|ok")

    elif check_type == "require_mention":
        no_mention = []
        for name, c in channels.items():
            if not isinstance(c, dict): continue
            if c.get("groupPolicy", "allowlist") != "disabled":
                if not c.get("requireMention", False):
                    no_mention.append(name)
        if no_mention: print(f"WARN|{', '.join(no_mention)}")
        else: print("PASS|ok")

except Exception:
    print("SKIP|error")
PYEOF
}

# ─── 1. DM Policy Check ─────────────────────────────────────────────────────

check_dm_policy() {
    echo -n "  DM policy: "

    if ! has_openclaw_config; then
        print_skip "Config not found"
        return
    fi

    local result
    result=$(_channel_check "dm_policy")
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

    local result
    result=$(_channel_check "allow_from")
    local status="${result%%|*}"
    local detail="${result#*|}"

    case "$status" in
        FAIL) print_fail "allowFrom: [\"*\"] found on: $detail - anyone can send messages" ;;
        PASS) print_pass "No wildcard allowFrom detected" ;;
        *) print_skip "Could not check allowFrom" ;;
    esac
}

# ─── 3. Group Policy Check ───────────────────────────────────────────────────

check_group_policy() {
    echo -n "  Group policy: "

    if ! has_openclaw_config; then
        print_skip "Config not found"
        return
    fi

    local result
    result=$(_channel_check "group_policy")
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
    result=$(_channel_check "require_mention")
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
