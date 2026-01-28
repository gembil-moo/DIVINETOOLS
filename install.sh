#!/bin/bash

echo "[*] Setting up DIVINETOOLS environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running in Termux
if [ -z "$TERMUX_VERSION" ]; then
    echo -e "${YELLOW}[!] Warning: This script is designed for Termux${NC}"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check dependencies
echo -e "[*] Checking dependencies..."
for cmd in curl wget git; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${YELLOW}[!] Installing $cmd...${NC}"
        pkg install -y $cmd 2>/dev/null || apt-get install -y $cmd 2>/dev/null
    fi
done

# Request storage permission (Termux)
if [ -n "$TERMUX_VERSION" ]; then
    echo -e "[*] Requesting storage access..."
    termux-setup-storage
fi

# Update system
echo -e "[*] Updating package lists..."
pkg update -y && pkg upgrade -y

# Install system packages
echo -e "[*] Installing required packages..."
pkg install -y \
    lua53 \
    luarocks \
    python \
    python-pip \
    tsu \
    figlet \
    toilet \
    ncurses-utils \
    android-tools \
    coreutils \
    clang \
    make \
    zip \
    unzip \
    jq 2>/dev/null

# Install Lua modules
echo -e "[*] Installing Lua modules..."
luarocks install lua-cjson 2>/dev/null || echo -e "${YELLOW}[!] Failed to install lua-cjson${NC}"
luarocks install luasocket 2>/dev/null || echo -e "${YELLOW}[!] Failed to install luasocket${NC}"

# Install Python libraries
echo -e "[*] Installing Python packages..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt 2>/dev/null || echo -e "${YELLOW}[!] Failed to install Python packages${NC}"
else
    echo -e "${YELLOW}[!] requirements.txt not found${NC}"
    pip install pyfiglet rich 2>/dev/null
fi

# Create necessary directories
echo -e "[*] Creating directory structure..."
mkdir -p config logs scripts/autoexec scripts/divine src/modules

# Set permissions
echo -e "[*] Setting permissions..."
chmod +x run.sh
chmod +x install.sh

# Check for root access
if su -c "echo 'Root check'" &>/dev/null; then
    echo -e "${GREEN}[+] Root access available${NC}"
else
    echo -e "${YELLOW}[!] Root access not available. Some features may be limited.${NC}"
fi

# Create example config if not exists
if [ ! -f "config/config.json" ] && [ -f "config.example.json" ]; then
    cp config.example.json config/config.json
    echo -e "${GREEN}[+] Created default config${NC}"
fi

echo -e "${GREEN}[+] Installation complete!${NC}"
echo -e "${GREEN}[+] Run with: ./run.sh${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "1. Edit config/config.json if needed"
echo -e "2. Run: ./run.sh"
echo -e "3. Select 'First Configuration' in menu"