#!/bin/bash

echo "[*] Setting up DIVINETOOLS environment..."

# Check if running in Termux
if [ -z "$TERMUX_VERSION" ]; then
    echo "[!] Warning: This script is designed for Termux"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check dependencies
echo "[*] Checking dependencies..."
for cmd in curl wget git; do
    if ! command -v $cmd &> /dev/null; then
        echo "[!] Installing $cmd..."
        pkg install -y $cmd 2>/dev/null || apt-get install -y $cmd 2>/dev/null
    fi
done

# Request storage permission (Termux)
if [ -n "$TERMUX_VERSION" ]; then
    echo "[*] Requesting storage access..."
    termux-setup-storage
fi

# Update system
echo "[*] Updating package lists..."
pkg update -y && pkg upgrade -y

# Install system packages
echo "[*] Installing required packages..."
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
echo "[*] Installing Lua modules..."
luarocks install lua-cjson 2>/dev/null || echo "[!] Failed to install lua-cjson"
luarocks install luasocket 2>/dev/null || echo "[!] Failed to install luasocket"

# Install Python libraries
echo "[*] Installing Python packages..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt 2>/dev/null || echo "[!] Failed to install Python packages"
else
    echo "[!] requirements.txt not found"
    pip install pyfiglet rich 2>/dev/null
fi

# Create necessary directories
echo "[*] Creating directory structure..."
mkdir -p config logs scripts/autoexec scripts/divine src/modules

# Set permissions
echo "[*] Setting permissions..."
chmod +x run.sh
chmod +x install.sh

# Check for root access
if su -c "echo 'Root check'" &>/dev/null; then
    echo "[+] Root access available"
else
    echo "[!] Root access not available. Some features may be limited."
fi

# Create example config if not exists
if [ ! -f "config/config.json" ] && [ -f "config.example.json" ]; then
    cp config.example.json config/config.json
    echo "[+] Created default config"
fi

echo "[+] Installation complete!"
echo "[+] Run with: ./run.sh"
echo ""
echo "Next steps:"
echo "1. Edit config/config.json if needed"
echo "2. Run: ./run.sh"
echo "3. Select 'First Configuration' in menu"