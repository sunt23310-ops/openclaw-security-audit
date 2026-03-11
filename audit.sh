#!/bin/bash
# =============================================================================
# OpenClaw Security Audit - Main Entry Point
# =============================================================================
# Interactive TUI menu for all security audit features
# Version: 1.0.0
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/reporter.sh"

# =============================================================================
# Banner
# =============================================================================

show_banner() {
    clear
    echo -e "${CYAN}"
    echo '   ___                    ____ _                '
    echo '  / _ \ _ __   ___ _ __ / ___| | __ ___      __'
    echo ' | | | |  _ \ / _ \  _ \ |   | |/ _` \ \ /\ / /'
    echo ' | |_| | |_) |  __/ | | | |___| | (_| |\ V  V / '
    echo '  \___/| .__/ \___|_| |_|\____|_|\__,_| \_/\_/  '
    echo '       |_|   Security Audit Tool v1.0.0'
    echo -e "${NC}"
    echo -e "${DIM}  Protect your OpenClaw, guard your privacy${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# =============================================================================
# Menu
# =============================================================================

show_menu() {
    echo ""
    echo -e "${BOLD}What would you like to do?${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Quick Check          ${DIM}(critical items, ~5 sec)${NC}"
    echo -e "  ${GREEN}[2]${NC} Full Security Audit  ${DIM}(all 6 modules, detailed)${NC}"
    echo -e "  ${GREEN}[3]${NC} Network Check        ${DIM}(ports, IP leak detection)${NC}"
    echo -e "  ${GREEN}[4]${NC} Interactive Fix      ${DIM}(guided security fixes)${NC}"
    echo -e "  ${GREEN}[5]${NC} Generate Report      ${DIM}(HTML or JSON format)${NC}"
    echo ""
    echo -e "  ${YELLOW}[H]${NC} Help"
    echo -e "  ${YELLOW}[Q]${NC} Quit"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# =============================================================================
# Actions
# =============================================================================

run_quick_check() {
    reset_counters
    echo ""
    echo -e "${BOLD}${CYAN}Quick Security Check${NC}"
    echo -e "${DIM}Checking critical security items...${NC}"

    bash "$SCRIPT_DIR/checks/gateway.sh"
    bash "$SCRIPT_DIR/checks/credentials.sh"

    print_summary
}

run_full_audit() {
    reset_counters
    echo ""
    echo -e "${BOLD}${CYAN}Full Security Audit${NC}"
    echo -e "${DIM}Running all 6 security modules...${NC}"

    bash "$SCRIPT_DIR/checks/gateway.sh"
    bash "$SCRIPT_DIR/checks/credentials.sh"
    bash "$SCRIPT_DIR/checks/channels.sh"
    bash "$SCRIPT_DIR/checks/tools.sh"
    bash "$SCRIPT_DIR/checks/network.sh"
    bash "$SCRIPT_DIR/checks/system.sh"

    print_summary
}

run_network_check() {
    reset_counters
    echo ""
    echo -e "${BOLD}${CYAN}Network Security Check${NC}"

    bash "$SCRIPT_DIR/checks/network.sh"

    print_summary
}

run_interactive_fix() {
    bash "$SCRIPT_DIR/fixes/interactive-fix.sh"
}

run_generate_report() {
    echo ""
    echo -e "${BOLD}Generate Audit Report${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} HTML Report"
    echo -e "  ${GREEN}[2]${NC} JSON Report"
    echo ""
    read -p "Format [1/2]: " fmt

    # Run full audit and capture results
    echo ""
    echo -e "${DIM}Running full audit for report...${NC}"

    # Run checks and collect structured data
    local checks=("gateway" "credentials" "channels" "tools" "network" "system")
    local categories=("Reconnaissance" "Credential Exposure" "Initial Access" "Execution" "Reconnaissance" "System Security")

    for i in "${!checks[@]}"; do
        local check="${checks[$i]}"
        local category="${categories[$i]}"
        local output
        output=$(bash "$SCRIPT_DIR/checks/${check}.sh" 2>/dev/null || true)

        # Parse output lines into report entries
        while IFS= read -r line; do
            if echo "$line" | grep -q "\[PASS\]"; then
                local detail
                detail=$(echo "$line" | sed 's/.*\[PASS\] //')
                add_report_entry "$category" "$check" "pass" "$detail"
            elif echo "$line" | grep -q "\[FAIL\]"; then
                detail=$(echo "$line" | sed 's/.*\[FAIL\] //')
                add_report_entry "$category" "$check" "fail" "$detail"
            elif echo "$line" | grep -q "\[WARN\]"; then
                detail=$(echo "$line" | sed 's/.*\[WARN\] //')
                add_report_entry "$category" "$check" "warn" "$detail"
            elif echo "$line" | grep -q "\[SKIP\]"; then
                detail=$(echo "$line" | sed 's/.*\[SKIP\] //')
                add_report_entry "$category" "$check" "skip" "$detail"
            fi
        done <<< "$output"
    done

    local report_file
    case "$fmt" in
        2)
            report_file=$(generate_json_report)
            ;;
        *)
            report_file=$(generate_html_report)
            ;;
    esac

    echo ""
    print_pass "Report saved to: $report_file"
}

show_help() {
    echo ""
    echo -e "${BOLD}OpenClaw Security Audit - Help${NC}"
    echo ""
    echo -e "${CYAN}What this tool checks:${NC}"
    echo "  1. Gateway   - Port binding, auth mode, TLS, token strength"
    echo "  2. Credentials - File permissions, plaintext keys, history leaks"
    echo "  3. Channels  - DM/group policies, allowFrom wildcards"
    echo "  4. Tools     - Sandbox mode, deny lists, tool profiles"
    echo "  5. Network   - Port exposure, IP leak detection"
    echo "  6. System    - macOS SIP, FileVault, TCC, iCloud sync"
    echo ""
    echo -e "${CYAN}Direct usage:${NC}"
    echo "  ./audit.sh                     # Interactive menu"
    echo "  bash checks/gateway.sh         # Run specific check"
    echo "  bash checks/credentials.sh     # Run specific check"
    echo "  bash fixes/interactive-fix.sh  # Run fixes"
    echo ""
    echo -e "${CYAN}Requirements:${NC}"
    echo "  - macOS (for system checks)"
    echo "  - Python 3 (for config parsing)"
    echo "  - OpenClaw installed (for full checks)"
    echo ""
}

# =============================================================================
# Main Loop
# =============================================================================

main() {
    show_banner

    while true; do
        show_menu
        read -p "Choose [1-5, H, Q]: " choice

        case "$choice" in
            1) run_quick_check ;;
            2) run_full_audit ;;
            3) run_network_check ;;
            4) run_interactive_fix ;;
            5) run_generate_report ;;
            [Hh]) show_help ;;
            [Qq])
                echo ""
                echo -e "${DIM}Stay safe!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Try again.${NC}"
                ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
        show_banner
    done
}

main "$@"
