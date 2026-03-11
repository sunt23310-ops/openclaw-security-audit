#!/bin/bash
# =============================================================================
# OpenClaw Security Audit - Credentials Security Check
# =============================================================================
# Checks: file permissions, plaintext API keys, shell history leaks
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "Credentials Security"

# ─── 1. State Directory Permission ───────────────────────────────────────────

check_state_dir_permission() {
    echo -n "  State directory permission: "

    if [ ! -d "$OPENCLAW_STATE_DIR" ]; then
        print_skip "OpenClaw state dir not found ($OPENCLAW_STATE_DIR)"
        return
    fi

    local perm
    perm=$(get_file_permission "$OPENCLAW_STATE_DIR")

    if [ "$perm" = "700" ]; then
        print_pass "~/.openclaw is 700 (owner-only)"
    elif [ "$perm" = "750" ]; then
        print_warn "~/.openclaw is 750 (group-readable, recommend 700)"
    else
        print_fail "~/.openclaw is $perm (should be 700)"
    fi
}

# ─── 2. Env File Permission ─────────────────────────────────────────────────

check_env_file_permission() {
    echo -n "  .env file permission: "

    if [ ! -f "$OPENCLAW_ENV_FILE" ]; then
        print_skip "No .env file found"
        return
    fi

    local perm
    perm=$(get_file_permission "$OPENCLAW_ENV_FILE")

    if [ "$perm" = "600" ]; then
        print_pass ".env file is 600 (owner read/write only)"
    else
        print_fail ".env file is $perm (should be 600)"
    fi
}

# ─── 3. Config File Permission ───────────────────────────────────────────────

check_config_file_permission() {
    echo -n "  Config file permission: "

    if [ ! -f "$OPENCLAW_CONFIG" ]; then
        print_skip "Config not found"
        return
    fi

    local perm
    perm=$(get_file_permission "$OPENCLAW_CONFIG")

    case "$perm" in
        600|640)
            print_pass "openclaw.json is $perm"
            ;;
        644)
            print_warn "openclaw.json is 644 (world-readable, recommend 600)"
            ;;
        *)
            print_fail "openclaw.json is $perm (should be 600)"
            ;;
    esac
}

# ─── 4. Plaintext API Key Detection ─────────────────────────────────────────

check_plaintext_keys() {
    echo -n "  Plaintext API keys in config: "

    if [ ! -f "$OPENCLAW_CONFIG" ]; then
        print_skip "Config not found"
        return
    fi

    # Search for common API key patterns in the config file
    local key_patterns="sk-ant-|sk-proj-|sk-|gsk_|AIza|xai-|hf_|AKIA"
    local found
    found=$(grep -cE "$key_patterns" "$OPENCLAW_CONFIG" 2>/dev/null || echo "0")

    if [ "$found" -gt 0 ]; then
        print_fail "Found $found potential plaintext API key(s) - use SecretRef instead"
    else
        print_pass "No plaintext API keys detected"
    fi
}

# ─── 5. Auth Profiles Permission ─────────────────────────────────────────────

check_auth_profiles() {
    echo -n "  Agent auth-profiles: "

    if [ ! -d "$OPENCLAW_AGENTS_DIR" ]; then
        print_skip "No agents directory found"
        return
    fi

    local bad_count=0
    local total=0

    while IFS= read -r -d '' profile; do
        total=$((total + 1))
        local perm
        perm=$(get_file_permission "$profile")
        if [ "$perm" != "600" ] && [ "$perm" != "640" ]; then
            bad_count=$((bad_count + 1))
        fi
    done < <(find "$OPENCLAW_AGENTS_DIR" -name "auth-profiles.json" -print0 2>/dev/null)

    if [ "$total" -eq 0 ]; then
        print_skip "No auth-profiles.json files found"
    elif [ "$bad_count" -eq 0 ]; then
        print_pass "All $total auth-profiles.json file(s) have secure permissions"
    else
        print_fail "$bad_count of $total auth-profiles.json file(s) have loose permissions"
    fi
}

# ─── 6. Shell History Leak ───────────────────────────────────────────────────

check_shell_history() {
    echo -n "  Shell history leak: "

    local history_files=(
        "$HOME/.zsh_history"
        "$HOME/.bash_history"
        "$HOME/.zhistory"
    )

    local leak_count=0
    local leak_files=""
    local patterns="OPENCLAW_GATEWAY_TOKEN|ANTHROPIC_API_KEY|OPENAI_API_KEY|sk-ant-|sk-proj-"

    for hfile in "${history_files[@]}"; do
        if [ -f "$hfile" ]; then
            local matches
            matches=$(grep -cE "$patterns" "$hfile" 2>/dev/null || echo "0")
            if [ "$matches" -gt 0 ]; then
                leak_count=$((leak_count + matches))
                leak_files="$leak_files $(basename "$hfile")"
            fi
        fi
    done

    if [ "$leak_count" -eq 0 ]; then
        print_pass "No API keys or tokens found in shell history"
    else
        print_warn "$leak_count potential leak(s) in:$leak_files"
    fi
}

# ─── 7. Credentials Directory ────────────────────────────────────────────────

check_credentials_dir() {
    echo -n "  Credentials directory: "

    if [ ! -d "$OPENCLAW_CREDENTIALS_DIR" ]; then
        print_skip "No credentials directory found"
        return
    fi

    local perm
    perm=$(get_file_permission "$OPENCLAW_CREDENTIALS_DIR")

    if [ "$perm" = "700" ]; then
        print_pass "credentials/ directory is 700"
    else
        print_fail "credentials/ directory is $perm (should be 700)"
    fi
}

# ─── Run All Checks ──────────────────────────────────────────────────────────

check_state_dir_permission
check_env_file_permission
check_config_file_permission
check_plaintext_keys
check_auth_profiles
check_shell_history
check_credentials_dir
