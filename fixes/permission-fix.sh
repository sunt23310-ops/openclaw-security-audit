#!/bin/bash
# =============================================================================
# OpenClaw Security Audit - Permission Fix
# =============================================================================
# Fixes: file permissions for state dir, .env, config, credentials
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "Permission Fix"

# ─── 1. State Directory ──────────────────────────────────────────────────────

fix_state_dir() {
    echo -e "${BOLD}1. Fix State Directory Permission${NC}"

    if [ ! -d "$OPENCLAW_STATE_DIR" ]; then
        print_skip "State directory not found ($OPENCLAW_STATE_DIR)"
        return
    fi

    local perm
    perm=$(get_file_permission "$OPENCLAW_STATE_DIR")

    if [ "$perm" = "700" ]; then
        print_pass "Already 700 - no fix needed"
        return
    fi

    echo "   Current: $perm | Target: 700 (owner-only)"
    if confirm_action "   Fix permission?"; then
        chmod 700 "$OPENCLAW_STATE_DIR"
        print_pass "Changed to 700"
    else
        echo "   Skipped."
    fi
    echo ""
}

# ─── 2. .env File ────────────────────────────────────────────────────────────

fix_env_file() {
    echo -e "${BOLD}2. Fix .env File Permission${NC}"

    if [ ! -f "$OPENCLAW_ENV_FILE" ]; then
        print_skip "No .env file found"
        return
    fi

    local perm
    perm=$(get_file_permission "$OPENCLAW_ENV_FILE")

    if [ "$perm" = "600" ]; then
        print_pass "Already 600 - no fix needed"
        return
    fi

    echo "   Current: $perm | Target: 600 (owner read/write)"
    if confirm_action "   Fix permission?"; then
        chmod 600 "$OPENCLAW_ENV_FILE"
        print_pass "Changed to 600"
    else
        echo "   Skipped."
    fi
    echo ""
}

# ─── 3. Config File ──────────────────────────────────────────────────────────

fix_config_file() {
    echo -e "${BOLD}3. Fix Config File Permission${NC}"

    if [ ! -f "$OPENCLAW_CONFIG" ]; then
        print_skip "Config not found"
        return
    fi

    local perm
    perm=$(get_file_permission "$OPENCLAW_CONFIG")

    if [ "$perm" = "600" ]; then
        print_pass "Already 600 - no fix needed"
        return
    fi

    echo "   Current: $perm | Target: 600"
    if confirm_action "   Fix permission?"; then
        chmod 600 "$OPENCLAW_CONFIG"
        print_pass "Changed to 600"
    else
        echo "   Skipped."
    fi
    echo ""
}

# ─── 4. Credentials Directory ────────────────────────────────────────────────

fix_credentials_dir() {
    echo -e "${BOLD}4. Fix Credentials Directory${NC}"

    if [ ! -d "$OPENCLAW_CREDENTIALS_DIR" ]; then
        print_skip "No credentials directory found"
        return
    fi

    local perm
    perm=$(get_file_permission "$OPENCLAW_CREDENTIALS_DIR")

    if [ "$perm" = "700" ]; then
        print_pass "Already 700 - no fix needed"
        return
    fi

    echo "   Current: $perm | Target: 700"
    if confirm_action "   Fix permission?"; then
        chmod 700 "$OPENCLAW_CREDENTIALS_DIR"
        print_pass "Changed to 700"
    else
        echo "   Skipped."
    fi
    echo ""
}

# ─── 5. Auth Profiles ────────────────────────────────────────────────────────

fix_auth_profiles() {
    echo -e "${BOLD}5. Fix Agent Auth Profiles${NC}"

    if [ ! -d "$OPENCLAW_AGENTS_DIR" ]; then
        print_skip "No agents directory found"
        return
    fi

    local fixed=0
    local total=0

    while IFS= read -r -d '' profile; do
        total=$((total + 1))
        local perm
        perm=$(get_file_permission "$profile")
        if [ "$perm" != "600" ]; then
            chmod 600 "$profile"
            fixed=$((fixed + 1))
        fi
    done < <(find "$OPENCLAW_AGENTS_DIR" -name "auth-profiles.json" -print0 2>/dev/null)

    if [ "$total" -eq 0 ]; then
        print_skip "No auth-profiles.json files found"
    elif [ "$fixed" -eq 0 ]; then
        print_pass "All $total auth-profiles.json file(s) already secure"
    else
        print_pass "Fixed $fixed of $total auth-profiles.json file(s)"
    fi
    echo ""
}

# ─── Run Fixes ────────────────────────────────────────────────────────────────

fix_state_dir
fix_env_file
fix_config_file
fix_credentials_dir
fix_auth_profiles
