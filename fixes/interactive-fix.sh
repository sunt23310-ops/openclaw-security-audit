#!/bin/bash
# =============================================================================
# OpenClaw Security Audit - Interactive Fix Menu
# =============================================================================
# Presents all available fixes in an interactive menu
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

echo ""
echo -e "${BOLD}${CYAN}OpenClaw Security - Interactive Fix${NC}"
echo -e "${DIM}All fixes require your confirmation before applying.${NC}"
echo ""
echo -e "  ${GREEN}[1]${NC} Gateway Fix        ${DIM}(bind localhost, generate token)${NC}"
echo -e "  ${GREEN}[2]${NC} Permission Fix     ${DIM}(file/dir permissions)${NC}"
echo -e "  ${GREEN}[3]${NC} Channel Fix        ${DIM}(DM policy, allowFrom, requireMention)${NC}"
echo -e "  ${GREEN}[4]${NC} Run All Fixes      ${DIM}(1 + 2 + 3 sequentially)${NC}"
echo ""
echo -e "  ${YELLOW}[Q]${NC} Back to main menu"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -p "Choose [1-4, Q]: " choice

case "$choice" in
    1)
        bash "$SCRIPT_DIR/gateway-fix.sh"
        ;;
    2)
        bash "$SCRIPT_DIR/permission-fix.sh"
        ;;
    3)
        bash "$SCRIPT_DIR/channel-fix.sh"
        ;;
    4)
        bash "$SCRIPT_DIR/gateway-fix.sh"
        bash "$SCRIPT_DIR/permission-fix.sh"
        bash "$SCRIPT_DIR/channel-fix.sh"
        ;;
    [Qq])
        echo "Returning to main menu."
        ;;
    *)
        echo "Invalid choice."
        ;;
esac
