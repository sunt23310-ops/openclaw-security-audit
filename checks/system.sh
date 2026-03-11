#!/bin/bash
# =============================================================================
# OpenClaw Security Audit - System Security Check
# =============================================================================
# Checks: macOS TCC, FileVault, SIP, iCloud sync path detection
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "System Security (macOS)"

if [ "$(uname)" != "Darwin" ]; then
    print_skip "System checks are macOS-only"
    echo ""
    return 0 2>/dev/null || exit 0
fi

# ─── 1. System Integrity Protection (SIP) ────────────────────────────────────

check_sip() {
    echo -n "  System Integrity Protection: "

    local sip_status
    sip_status=$(csrutil status 2>/dev/null || true)

    if echo "$sip_status" | grep -qi "enabled"; then
        print_pass "SIP is enabled"
    elif echo "$sip_status" | grep -qi "disabled"; then
        print_fail "SIP is disabled - system integrity compromised"
    else
        print_skip "Could not determine SIP status"
    fi
}

# ─── 2. FileVault ────────────────────────────────────────────────────────────

check_filevault() {
    echo -n "  FileVault disk encryption: "

    local fv_status
    fv_status=$(fdesetup status 2>/dev/null || true)

    if echo "$fv_status" | grep -qi "on"; then
        print_pass "FileVault is ON"
    elif echo "$fv_status" | grep -qi "off"; then
        print_warn "FileVault is OFF - disk is not encrypted"
    else
        print_skip "Could not determine FileVault status"
    fi
}

# ─── 3. TCC / Full Disk Access ───────────────────────────────────────────────

check_tcc_fda() {
    echo -n "  Full Disk Access (TCC): "

    # Check if OpenClaw-related processes have FDA
    local tcc_db="$HOME/Library/Application Support/com.apple.TCC/TCC.db"

    if [ ! -f "$tcc_db" ]; then
        print_skip "TCC database not accessible"
        return
    fi

    local fda_entries
    fda_entries=$(sqlite3 "$tcc_db" \
        "SELECT client FROM access WHERE service='kTCCServiceSystemPolicyAllFiles' AND auth_value=2;" \
        2>/dev/null || true)

    if [ -z "$fda_entries" ]; then
        print_pass "No applications have Full Disk Access"
        return
    fi

    # Check if Node.js or OpenClaw has FDA
    local risky=false
    while IFS= read -r client; do
        if echo "$client" | grep -qi "node\|openclaw\|terminal\|iterm\|warp"; then
            echo ""
            echo -n "    $client has FDA: "
            print_warn "OpenClaw may access all files through $client"
            risky=true
        fi
    done <<< "$fda_entries"

    if ! $risky; then
        print_pass "No OpenClaw-related apps have Full Disk Access"
    fi
}

# ─── 4. Camera & Microphone Access ───────────────────────────────────────────

check_camera_mic() {
    echo -n "  Camera/Microphone access: "

    local tcc_db="$HOME/Library/Application Support/com.apple.TCC/TCC.db"

    if [ ! -f "$tcc_db" ]; then
        print_skip "TCC database not accessible"
        return
    fi

    local cam_access
    cam_access=$(sqlite3 "$tcc_db" \
        "SELECT client FROM access WHERE service='kTCCServiceCamera' AND auth_value=2;" \
        2>/dev/null || true)

    local mic_access
    mic_access=$(sqlite3 "$tcc_db" \
        "SELECT client FROM access WHERE service='kTCCServiceMicrophone' AND auth_value=2;" \
        2>/dev/null || true)

    local issues=0

    if echo "$cam_access" | grep -qi "node\|openclaw"; then
        print_warn "Camera access granted to Node.js/OpenClaw process"
        issues=$((issues + 1))
    fi

    if echo "$mic_access" | grep -qi "node\|openclaw"; then
        if [ $issues -gt 0 ]; then
            echo -n "    Microphone: "
        fi
        print_warn "Microphone access granted to Node.js/OpenClaw process"
        issues=$((issues + 1))
    fi

    if [ $issues -eq 0 ]; then
        print_pass "No camera/microphone access for OpenClaw processes"
    fi
}

# ─── 5. Screen Recording Access ──────────────────────────────────────────────

check_screen_recording() {
    echo -n "  Screen recording access: "

    local tcc_db="$HOME/Library/Application Support/com.apple.TCC/TCC.db"

    if [ ! -f "$tcc_db" ]; then
        print_skip "TCC database not accessible"
        return
    fi

    local screen_access
    screen_access=$(sqlite3 "$tcc_db" \
        "SELECT client FROM access WHERE service='kTCCServiceScreenCapture' AND auth_value=2;" \
        2>/dev/null || true)

    if echo "$screen_access" | grep -qi "node\|openclaw"; then
        print_warn "Screen recording access granted to Node.js/OpenClaw"
    else
        print_pass "No screen recording access for OpenClaw processes"
    fi
}

# ─── 6. iCloud Sync Path Detection ───────────────────────────────────────────

check_icloud_sync() {
    echo -n "  iCloud sync exposure: "

    local icloud_drive="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
    local openclaw_real
    openclaw_real=$(realpath "$OPENCLAW_STATE_DIR" 2>/dev/null || echo "$OPENCLAW_STATE_DIR")

    if [ ! -d "$icloud_drive" ]; then
        print_pass "iCloud Drive not detected"
        return
    fi

    if [[ "$openclaw_real" == *"Mobile Documents"* ]] || [[ "$openclaw_real" == *"iCloud"* ]]; then
        print_fail "OpenClaw state dir is inside iCloud Drive - credentials may sync to cloud!"
    else
        print_pass "OpenClaw state dir is not in iCloud Drive"
    fi
}

# ─── 7. Gatekeeper Status ────────────────────────────────────────────────────

check_gatekeeper() {
    echo -n "  Gatekeeper: "

    local gk_status
    gk_status=$(spctl --status 2>/dev/null || true)

    if echo "$gk_status" | grep -qi "enabled\|assessments enabled"; then
        print_pass "Gatekeeper is enabled"
    elif echo "$gk_status" | grep -qi "disabled"; then
        print_warn "Gatekeeper is disabled"
    else
        print_skip "Could not determine Gatekeeper status"
    fi
}

# ─── Run All Checks ──────────────────────────────────────────────────────────

check_sip
check_filevault
check_tcc_fda
check_camera_mic
check_screen_recording
check_icloud_sync
check_gatekeeper
