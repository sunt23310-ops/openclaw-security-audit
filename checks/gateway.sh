#!/bin/bash
# =============================================================================
# OpenClaw Security Audit - Gateway Security Check
# =============================================================================
# Checks: port binding, auth mode, TLS, all OpenClaw ports exposure
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "Gateway Security"

# ─── 1. Gateway Port Binding ─────────────────────────────────────────────────

check_gateway_binding() {
    echo -n "  Gateway port binding: "

    if ! is_gateway_running; then
        print_skip "Gateway not running on port $OPENCLAW_GATEWAY_PORT"
        return
    fi

    local bind_info
    bind_info=$(lsof -i ":${OPENCLAW_GATEWAY_PORT}" -sTCP:LISTEN 2>/dev/null || true)

    if echo "$bind_info" | grep -q "\*:${OPENCLAW_GATEWAY_PORT}\|0\.0\.0\.0:"; then
        print_fail "Gateway bound to 0.0.0.0 (exposed to all interfaces!)"
    elif echo "$bind_info" | grep -q "127\.0\.0\.1\|localhost"; then
        print_pass "Gateway securely bound to localhost"
    else
        print_warn "Gateway binding could not be determined"
    fi
}

# ─── 2. Auth Mode ────────────────────────────────────────────────────────────

check_auth_mode() {
    echo -n "  Auth mode: "

    if ! has_openclaw_config; then
        print_skip "Config not found at $OPENCLAW_CONFIG"
        return
    fi

    local auth_mode
    auth_mode=$(read_config_value "gateway.auth.mode" 2>/dev/null)

    if [ -z "$auth_mode" ]; then
        # Check if gateway section exists at all
        local gateway_cfg
        gateway_cfg=$(read_config_value "gateway" 2>/dev/null)
        if [ -z "$gateway_cfg" ]; then
            print_skip "No gateway config section found"
        else
            print_warn "Auth mode not explicitly set (defaults may apply)"
        fi
        return
    fi

    case "$auth_mode" in
        none)
            print_fail "Auth mode is 'none' - no authentication required!"
            ;;
        token|password|tailscale|device-token|trusted-proxy)
            print_pass "Auth mode: $auth_mode"
            ;;
        *)
            print_warn "Unknown auth mode: $auth_mode"
            ;;
    esac
}

# ─── 3. Gateway Token Strength ───────────────────────────────────────────────

check_token_strength() {
    echo -n "  Token strength: "

    if ! has_openclaw_config; then
        print_skip "Config not found"
        return
    fi

    local auth_mode
    auth_mode=$(read_config_value "gateway.auth.mode" 2>/dev/null)

    if [ "$auth_mode" != "token" ]; then
        print_skip "Auth mode is not 'token'"
        return
    fi

    # Check env var first
    local token="${OPENCLAW_GATEWAY_TOKEN:-}"

    if [ -z "$token" ]; then
        # Try config file
        token=$(read_config_value "gateway.auth.token" 2>/dev/null)
    fi

    if [ -z "$token" ]; then
        print_warn "Token configured but value not found (may use SecretRef)"
        return
    fi

    local token_len=${#token}
    if [ "$token_len" -lt 20 ]; then
        print_fail "Token too short ($token_len chars, minimum 20 recommended)"
    elif [ "$token_len" -lt 40 ]; then
        print_warn "Token is acceptable but could be stronger ($token_len chars)"
    else
        print_pass "Token strength sufficient ($token_len chars)"
    fi
}

# ─── 4. TLS Configuration ────────────────────────────────────────────────────

check_tls() {
    echo -n "  TLS/HTTPS: "

    if ! has_openclaw_config; then
        print_skip "Config not found"
        return
    fi

    local tls_cert
    tls_cert=$(read_config_value "gateway.tls.cert" 2>/dev/null)

    if [ -n "$tls_cert" ]; then
        print_pass "TLS configured (cert: $tls_cert)"
    else
        local bind
        bind=$(read_config_value "gateway.bind" 2>/dev/null)
        if [ "$bind" = "0.0.0.0" ] || [ "$bind" = "::" ]; then
            print_warn "No TLS configured and gateway is exposed - HTTPS strongly recommended"
        else
            print_info "No TLS (acceptable for localhost-only binding)"
            print_pass "TLS not needed for local binding"
        fi
    fi
}

# ─── 5. All OpenClaw Ports Scan ──────────────────────────────────────────────

check_all_ports() {
    echo -n "  Additional port exposure: "

    local exposed_ports=()

    for port in "${OPENCLAW_ALL_PORTS[@]}"; do
        [ "$port" -eq "$OPENCLAW_GATEWAY_PORT" ] && continue
        local listen_info
        listen_info=$(lsof -i ":${port}" -sTCP:LISTEN 2>/dev/null || true)
        if echo "$listen_info" | grep -q "\*:${port}\|0\.0\.0\.0:"; then
            exposed_ports+=("$port")
        fi
    done

    # Check CDP port range (sample check)
    for port in $OPENCLAW_CDP_PORT_MIN $((OPENCLAW_CDP_PORT_MIN + 50)) $OPENCLAW_CDP_PORT_MAX; do
        local listen_info
        listen_info=$(lsof -i ":${port}" -sTCP:LISTEN 2>/dev/null || true)
        if echo "$listen_info" | grep -q "\*:${port}\|0\.0\.0\.0:"; then
            exposed_ports+=("$port")
        fi
    done

    if [ ${#exposed_ports[@]} -eq 0 ]; then
        print_pass "No additional OpenClaw ports exposed"
    else
        print_fail "Exposed ports: ${exposed_ports[*]}"
    fi
}

# ─── Run All Checks ──────────────────────────────────────────────────────────

check_gateway_binding
check_auth_mode
check_token_strength
check_tls
check_all_ports
