#!/bin/bash
# =============================================================================
# Test Runner for OpenClaw Security Audit
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}OpenClaw Security Audit - Test Suite${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check for bats
if command -v bats &>/dev/null; then
    BATS_CMD="bats"
elif [ -x "$SCRIPT_DIR/bats/bin/bats" ]; then
    BATS_CMD="$SCRIPT_DIR/bats/bin/bats"
else
    echo -e "${YELLOW}BATS not found. Running basic validation tests...${NC}"
    echo ""

    PASS=0
    FAIL=0

    run_test() {
        local name="$1"
        local cmd="$2"
        echo -n "  $name: "
        if eval "$cmd" &>/dev/null; then
            echo -e "${GREEN}PASS${NC}"
            PASS=$((PASS + 1))
        else
            echo -e "${RED}FAIL${NC}"
            FAIL=$((FAIL + 1))
        fi
    }

    echo -e "${BOLD}File Structure Tests${NC}"
    run_test "audit.sh exists" "[ -f '$PROJECT_DIR/audit.sh' ]"
    run_test "lib/common.sh exists" "[ -f '$PROJECT_DIR/lib/common.sh' ]"
    run_test "lib/reporter.sh exists" "[ -f '$PROJECT_DIR/lib/reporter.sh' ]"
    run_test "checks/gateway.sh exists" "[ -f '$PROJECT_DIR/checks/gateway.sh' ]"
    run_test "checks/credentials.sh exists" "[ -f '$PROJECT_DIR/checks/credentials.sh' ]"
    run_test "checks/channels.sh exists" "[ -f '$PROJECT_DIR/checks/channels.sh' ]"
    run_test "checks/tools.sh exists" "[ -f '$PROJECT_DIR/checks/tools.sh' ]"
    run_test "checks/network.sh exists" "[ -f '$PROJECT_DIR/checks/network.sh' ]"
    run_test "checks/system.sh exists" "[ -f '$PROJECT_DIR/checks/system.sh' ]"
    run_test "fixes/interactive-fix.sh exists" "[ -f '$PROJECT_DIR/fixes/interactive-fix.sh' ]"

    echo ""
    echo -e "${BOLD}Syntax Tests${NC}"
    run_test "audit.sh syntax" "bash -n '$PROJECT_DIR/audit.sh'"
    run_test "lib/common.sh syntax" "bash -n '$PROJECT_DIR/lib/common.sh'"
    run_test "lib/reporter.sh syntax" "bash -n '$PROJECT_DIR/lib/reporter.sh'"
    run_test "checks/gateway.sh syntax" "bash -n '$PROJECT_DIR/checks/gateway.sh'"
    run_test "checks/credentials.sh syntax" "bash -n '$PROJECT_DIR/checks/credentials.sh'"
    run_test "checks/channels.sh syntax" "bash -n '$PROJECT_DIR/checks/channels.sh'"
    run_test "checks/tools.sh syntax" "bash -n '$PROJECT_DIR/checks/tools.sh'"
    run_test "checks/network.sh syntax" "bash -n '$PROJECT_DIR/checks/network.sh'"
    run_test "checks/system.sh syntax" "bash -n '$PROJECT_DIR/checks/system.sh'"
    run_test "fixes/gateway-fix.sh syntax" "bash -n '$PROJECT_DIR/fixes/gateway-fix.sh'"
    run_test "fixes/permission-fix.sh syntax" "bash -n '$PROJECT_DIR/fixes/permission-fix.sh'"
    run_test "fixes/channel-fix.sh syntax" "bash -n '$PROJECT_DIR/fixes/channel-fix.sh'"

    echo ""
    echo -e "${BOLD}Common Library Tests${NC}"
    run_test "common.sh sources cleanly" "source '$PROJECT_DIR/lib/common.sh'"
    run_test "OPENCLAW_STATE_DIR defined" "source '$PROJECT_DIR/lib/common.sh' && [ -n \"\$OPENCLAW_STATE_DIR\" ]"
    run_test "OPENCLAW_GATEWAY_PORT is 18789" "source '$PROJECT_DIR/lib/common.sh' && [ \"\$OPENCLAW_GATEWAY_PORT\" = '18789' ]"
    run_test "print_pass function exists" "source '$PROJECT_DIR/lib/common.sh' && type print_pass &>/dev/null"
    run_test "print_fail function exists" "source '$PROJECT_DIR/lib/common.sh' && type print_fail &>/dev/null"
    run_test "read_config_value function exists" "source '$PROJECT_DIR/lib/common.sh' && type read_config_value &>/dev/null"
    run_test "Python3 available" "command -v python3"

    echo ""
    echo -e "${BOLD}Permission Tests${NC}"
    run_test "audit.sh is readable" "[ -r '$PROJECT_DIR/audit.sh' ]"
    run_test "No real secrets in repo" "! grep -rqE 'sk-ant-[a-zA-Z0-9]{20,}|sk-proj-[a-zA-Z0-9]{20,}|AKIA[A-Z0-9]{16}' '$PROJECT_DIR/lib/' '$PROJECT_DIR/checks/' '$PROJECT_DIR/fixes/' 2>/dev/null"

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Results: ${GREEN}$PASS passed${NC} | ${RED}$FAIL failed${NC}"

    if [ "$FAIL" -gt 0 ]; then
        exit 1
    fi
    exit 0
fi

# Run BATS tests if available
echo -e "${BOLD}Running BATS tests...${NC}"
echo ""

$BATS_CMD "$SCRIPT_DIR"/*.bats
