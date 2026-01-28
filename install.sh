#!/bin/bash

echo "[*] Setting up DIVINETOOLS environment..."

# Termux storage
termux-setup-storage

# Update system
pkg update -y && pkg upgrade -y

# Install system packages
pkg install -y \
lua53 \
luarocks \
python \
tsu \
figlet \
toilet \
ncurses-utils \
android-tools \
coreutils \
clang \
make

# Install Lua modules
echo "[*] Installing Lua modules..."
luarocks install lua-cjson
luarocks install luasocket

# Install Python libraries
echo "[*] Installing Python packages..."
pip install -r requirements.txt

# Permission
chmod +x run.sh

echo "[+] Installation complete!"
echo "[+] Run with: ./run.sh"
