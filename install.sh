#!/bin/bash

# DIVINETOOLS Installer

# Colors
C='\033[1;36m' # Cyan
GREEN='\033[0;32m'
NC='\033[0m'

# Header
header() {
    clear
    echo -e "${C}"
    echo "   ___  _____    _(_)___  ___"
    echo "  / _ \/  _/ |  / / / _ \/ _ \\"
    echo " / // // / | | / / / // /  __/"
    echo "/____/___/ |___/_/_/_//_/\\___/"
    echo -e "${NC}"
    echo -e "${C}=== DIVINE TOOLS INSTALLER ===${NC}"
    echo ""
}

header

# 1. Update & Install Dependencies
echo -e "${C}[*] Updating and installing dependencies...${NC}"
pkg update -y >/dev/null 2>&1
pkg install -y git jq tsu ncurses-utils nano >/dev/null 2>&1

# 2. Create Directory Structure
echo -e "${C}[*] Creating directory structure...${NC}"
mkdir -p config logs workspace

# 3. Set Permissions
echo -e "${C}[*] Setting permissions...${NC}"
chmod +x *.sh 2>/dev/null

# 4. Finish
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}      INSTALLATION SUCCESSFUL!          ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}To start, run: bash divine.sh${NC}"
echo ""