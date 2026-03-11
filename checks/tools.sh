#!/bin/bash
# =============================================================================
# OpenClaw Security Audit - Tools & Sandbox Check
# =============================================================================
# Checks: sandbox mode, tools.deny list, tool profiles, denyCommands
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "Tools & Sandbox Security"

# ─── 1. Sandbox Mode ─────────────────────────────────────────────────────────

check_sandbox_mode() {
    echo -n "  Sandbox mode: "

    if ! has_openclaw_config; then
        print_skip "Config not found"
        return
    fi

    local sandbox_mode
    sandbox_mode=$(read_config_value "sandbox.mode" 2>/dev/null)

    if [ -z "$sandbox_mode" ]; then
        print_warn "Sandbox not configured (non-main sessions have full host access)"
        return
    fi

    case "$sandbox_mode" in
        off)
            print_fail "Sandbox is OFF - all sessions have full host access"
            ;;
        non-main)
            print_pass "Sandbox: non-main sessions are sandboxed"
            ;;
        all)
            print_pass "Sandbox: all sessions are sandboxed"
            ;;
        *)
            print_warn "Unknown sandbox mode: $sandbox_mode"
            ;;
    esac
}

# ─── 2. Docker Availability for Sandbox ──────────────────────────────────────

check_docker_sandbox() {
    echo -n "  Docker for sandbox: "

    local sandbox_mode
    sandbox_mode=$(read_config_value "sandbox.mode" 2>/dev/null)

    if [ "$sandbox_mode" = "off" ] || [ -z "$sandbox_mode" ]; then
        print_skip "Sandbox not enabled"
        return
    fi

    if command -v docker &>/dev/null; then
        if docker ps &>/dev/null 2>&1; then
            print_pass "Docker is available and running"
        else
            print_warn "Docker installed but not running (sandbox may fail)"
        fi
    else
        print_fail "Docker not installed (required for sandbox mode)"
    fi
}

# ─── 3. Tools Deny List ──────────────────────────────────────────────────────

check_tools_deny() {
    echo -n "  Tools deny list: "

    if ! has_openclaw_config; then
        print_skip "Config not found"
        return
    fi

    local deny_list
    deny_list=$(read_config_value "tools.deny" 2>/dev/null)

    if [ -z "$deny_list" ] || [ "$deny_list" = "[]" ]; then
        print_warn "No tools.deny list configured - all tools are allowed"
    else
        print_pass "Tools deny list is configured"
    fi
}

# ─── 4. DenyCommands (Shell Command Blacklist) ───────────────────────────────

check_deny_commands() {
    echo -n "  Shell command blacklist: "

    if ! has_openclaw_config; then
        print_skip "Config not found"
        return
    fi

    local deny_cmds
    deny_cmds=$(read_config_value "tools.denyCommands" 2>/dev/null)

    if [ -z "$deny_cmds" ] || [ "$deny_cmds" = "[]" ]; then
        # Also check at agents level
        deny_cmds=$(read_config_value "agents.defaults.tools.denyCommands" 2>/dev/null)
    fi

    if [ -z "$deny_cmds" ] || [ "$deny_cmds" = "[]" ]; then
        print_warn "No denyCommands configured - AI can execute any shell command"
    else
        # Check if common dangerous commands are blocked
        local dangerous_cmds=("rm -rf" "curl.*|.*bash" "chmod 777" "eval" "nc -l")
        local missing=()

        for cmd in "${dangerous_cmds[@]}"; do
            if ! echo "$deny_cmds" | grep -qi "$cmd"; then
                missing+=("$cmd")
            fi
        done

        if [ ${#missing[@]} -eq 0 ]; then
            print_pass "denyCommands configured with key dangerous commands blocked"
        else
            print_warn "denyCommands configured but missing: ${missing[*]}"
        fi
    fi
}

# ─── 5. Tool Profiles for Non-Main Sessions ─────────────────────────────────

check_tool_profiles() {
    echo -n "  Non-main session tool profile: "

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
    # Check if non-main sessions have restricted tool profiles
    agents = cfg.get("agents", {})
    defaults = agents.get("defaults", {})
    tools_cfg = defaults.get("tools", {})
    profile = tools_cfg.get("profile", "")
    if profile == "full":
        print("WARN|full")
    elif profile in ("minimal", "coding", "messaging"):
        print(f"PASS|{profile}")
    elif profile:
        print(f"PASS|{profile}")
    else:
        print("INFO|default")
except: print("SKIP|error")
PYEOF
    )

    local status="${result%%|*}"
    local detail="${result#*|}"

    case "$status" in
        WARN) print_warn "Default tool profile is 'full' - consider restricting non-main sessions" ;;
        PASS) print_pass "Tool profile: $detail" ;;
        INFO) print_pass "Using default tool profile" ;;
        *) print_skip "Could not determine tool profiles" ;;
    esac
}

# ─── 6. Browser CDP Port Exposure ────────────────────────────────────────────

check_cdp_exposure() {
    echo -n "  Browser CDP ports: "

    local exposed=0
    for port in $(seq $OPENCLAW_CDP_PORT_MIN 10 $OPENCLAW_CDP_PORT_MAX); do
        local listen
        listen=$(lsof -i ":${port}" -sTCP:LISTEN 2>/dev/null || true)
        if echo "$listen" | grep -q "\*:${port}\|0\.0\.0\.0:"; then
            exposed=$((exposed + 1))
        fi
    done

    if [ "$exposed" -eq 0 ]; then
        print_pass "No CDP ports exposed on public interfaces"
    else
        print_fail "$exposed CDP port(s) exposed (range $OPENCLAW_CDP_PORT_MIN-$OPENCLAW_CDP_PORT_MAX)"
    fi
}

# ─── Run All Checks ──────────────────────────────────────────────────────────

check_sandbox_mode
check_docker_sandbox
check_tools_deny
check_deny_commands
check_tool_profiles
check_cdp_exposure
