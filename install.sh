#!/bin/bash

echo "[*] Setting up DIVINETOOLS environment..."

# Setup storage permission
termux-setup-storage

# Update & Install System Packages
pkg update -y && pkg upgrade -y
pkg install -y lua53 tsu python figlet toilet ncurses-utils android-tools lua-cjson

# Install Python Libraries
pip install -r requirements.txt

chmod +x run.sh
echo "[+] Installation complete! Run ./run.sh to start."