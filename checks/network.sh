#!/bin/bash
# =============================================================================
# OpenClaw Security Audit - Network Security Check
# =============================================================================
# Checks: all port exposure, local listeners, IP leak detection
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

print_header "Network Security"

# ─── 1. Local Listener Scan ──────────────────────────────────────────────────

check_local_listeners() {
    echo -n "  Local listener scan: "

    local exposed_ports=()
    local all_ports=(18789 18790 18791 18793 1455)

    for port in "${all_ports[@]}"; do
        local listen_info
        listen_info=$(lsof -i ":${port}" -sTCP:LISTEN 2>/dev/null || true)
        if [ -n "$listen_info" ]; then
            if echo "$listen_info" | grep -q "\*:${port}\|0\.0\.0\.0:"; then
                exposed_ports+=("${port}(public)")
            fi
        fi
    done

    if [ ${#exposed_ports[@]} -eq 0 ]; then
        print_pass "No OpenClaw ports exposed on public interfaces"
    else
        print_fail "Publicly exposed: ${exposed_ports[*]}"
    fi
}

# ─── 2. Suspicious Outbound Connections ──────────────────────────────────────

check_outbound_connections() {
    echo -n "  Outbound connections: "

    if ! is_gateway_running; then
        print_skip "Gateway not running"
        return
    fi

    # Find the gateway PID
    local gw_pid
    gw_pid=$(lsof -i ":${OPENCLAW_GATEWAY_PORT}" -sTCP:LISTEN -t 2>/dev/null | head -1)

    if [ -z "$gw_pid" ]; then
        print_skip "Could not determine gateway PID"
        return
    fi

    # Count established outbound connections
    local conn_count
    conn_count=$(lsof -p "$gw_pid" -i -sTCP:ESTABLISHED 2>/dev/null | grep -cv "^COMMAND" || echo "0")

    if [ "$conn_count" -le 10 ]; then
        print_pass "$conn_count active outbound connection(s)"
    elif [ "$conn_count" -le 30 ]; then
        print_warn "$conn_count active connections (may be normal with many channels)"
    else
        print_warn "$conn_count active connections (unusually high)"
    fi
}

# ─── 3. Firewall Status ─────────────────────────────────────────────────────

check_firewall() {
    echo -n "  macOS Firewall: "

    if [ "$(uname)" != "Darwin" ]; then
        print_skip "Not macOS"
        return
    fi

    local fw_status
    fw_status=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || true)

    if echo "$fw_status" | grep -qi "enabled"; then
        print_pass "macOS Firewall is enabled"
    else
        print_warn "macOS Firewall is disabled"
    fi
}

# ─── 4. IP Leak Detection (Local Check) ──────────────────────────────────────

check_ip_leak_local() {
    echo -n "  Public IP exposure (local): "

    # Check if any OpenClaw port is reachable from outside
    local public_ip
    public_ip=$(curl -s --connect-timeout 5 https://api.ipify.org 2>/dev/null || true)

    if [ -z "$public_ip" ]; then
        print_skip "Could not determine public IP (no internet?)"
        return
    fi

    print_info "Your public IP: $public_ip"

    # Check if gateway port is potentially forwarded
    local gateway_listen
    gateway_listen=$(lsof -i ":${OPENCLAW_GATEWAY_PORT}" -sTCP:LISTEN 2>/dev/null || true)

    if [ -z "$gateway_listen" ]; then
        echo -n "  Port forwarding risk: "
        print_pass "Gateway not running - no exposure risk"
    elif echo "$gateway_listen" | grep -q "0\.0\.0\.0\|\*:"; then
        echo -n "  Port forwarding risk: "
        print_fail "Gateway on 0.0.0.0 - may be reachable at $public_ip:$OPENCLAW_GATEWAY_PORT"
    else
        echo -n "  Port forwarding risk: "
        print_pass "Gateway on localhost only"
    fi
}

# ─── 5. External IP Leak Database Check ──────────────────────────────────────

check_ip_leak_external() {
    echo -n "  External leak database: "

    local public_ip
    public_ip=$(curl -s --connect-timeout 5 https://api.ipify.org 2>/dev/null || true)

    if [ -z "$public_ip" ]; then
        print_skip "Could not determine public IP"
        return
    fi

    echo ""
    echo -e "    ${YELLOW}This check will send your public IP ($public_ip) to external services.${NC}"
    echo -e "    ${YELLOW}Services: Shodan, Censys (public search engines)${NC}"

    if ! confirm_action "    Proceed with external leak check?"; then
        print_skip "User declined external check"
        return
    fi

    echo -n "    Shodan: "
    local shodan_result
    shodan_result=$(curl -s --connect-timeout 10 "https://internetdb.shodan.io/${public_ip}" 2>/dev/null || true)

    if [ -n "$shodan_result" ]; then
        local open_ports
        open_ports=$(echo "$shodan_result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(','.join(map(str,d.get('ports',[]))))" 2>/dev/null || true)

        if [ -z "$open_ports" ]; then
            print_pass "Not found in Shodan database"
        else
            # Check if any OpenClaw ports are in the list
            local oc_exposed=false
            for port in "${OPENCLAW_ALL_PORTS[@]}"; do
                if echo ",$open_ports," | grep -q ",${port},"; then
                    oc_exposed=true
                    break
                fi
            done

            if $oc_exposed; then
                print_fail "OpenClaw ports found in Shodan! Open ports: $open_ports"
            else
                print_warn "IP in Shodan (ports: $open_ports) but no OpenClaw ports exposed"
            fi
        fi
    else
        print_skip "Could not reach Shodan"
    fi
}

# ─── Run All Checks ──────────────────────────────────────────────────────────

check_local_listeners
check_outbound_connections
check_firewall
check_ip_leak_local
check_ip_leak_external
