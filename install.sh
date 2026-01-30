#!/bin/bash

# DIVINETOOLS Installer

# --- UI Colors ---
GREEN='\033[0;32m'
NC='\033[0m'

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}      DIVINETOOLS INSTALLER             ${NC}"
echo -e "${GREEN}========================================${NC}"

# 1. Root Check
echo -e "${GREEN}[*] Checking Root Access...${NC}"
if ! command -v su >/dev/null 2>&1 || ! su -c "id" >/dev/null 2>&1; then
    echo -e "${GREEN}[!] WARNING: Root access not found!${NC}"
    echo -e "${GREEN}[!] Device optimization features will not work.${NC}"
else
    echo -e "${GREEN}[OK] Root access detected.${NC}"
fi

# 2. Dependencies
echo -e "${GREEN}[*] Installing dependencies...${NC}"
pkg update -y >/dev/null 2>&1
pkg install -y jq tsu ncurses-utils git >/dev/null 2>&1
echo -e "${GREEN}[OK] Dependencies installed.${NC}"

# 3. Setup Directories
echo -e "${GREEN}[*] Setting up directories...${NC}"
mkdir -p config logs workspace
chmod +x *.sh 2>/dev/null
echo -e "${GREEN}[OK] Directories created: config, logs, workspace${NC}"

# 4. Finish
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}      INSTALLATION SUCCESSFUL!          ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}To start, run: bash divine.sh${NC}"
echo ""