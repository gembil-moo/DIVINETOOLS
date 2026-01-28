#!/bin/bash

echo "[*] Setting up DIVINETOOLS environment..."
echo "[*] Working directory: $(pwd)"

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

# Set permissions - DENGAN CEK FILE DULU!
echo "[*] Setting permissions..."
if [ -f "run.sh" ]; then
    chmod +x run.sh
    echo "[+] run.sh permissions set"
else
    echo "[!] run.sh not found - creating basic run.sh..."
    cat > run.sh << 'EOF'
#!/bin/bash
echo "[*] DIVINETOOLS Launcher"
echo "[*] Place main.lua in src/ folder"
echo "[!] Please configure the application first"
EOF
    chmod +x run.sh
fi

if [ -f "install.sh" ]; then
    chmod +x install.sh
    echo "[+] install.sh permissions set"
fi

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
elif [ ! -f "config/config.json" ] && [ ! -f "config.example.json" ]; then
    echo "[*] Creating minimal config.json..."
    mkdir -p config
    cat > config/config.json << 'EOF'
{
    "version": "2.0.0",
    "first_run": true,
    "log_level": "info"
}
EOF
    echo "[+] Created minimal config"
fi

echo ""
echo "[+] Installation complete!"
echo "[+] Run with: ./run.sh"
echo ""
echo "Next steps:"
echo "1. Edit config/config.json if needed"
echo "2. Run: ./run.sh"
echo "3. Select 'First Configuration' in menu"
echo ""
echo "Current directory contents:"
ls -la