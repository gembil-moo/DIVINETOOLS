#!/bin/bash

# DIVINETOOLS Installer - Mobile Optimized

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- UI Functions ---
print_info() { echo -e "${BLUE}[*] $1${NC}"; }
print_ok() { echo -e "${GREEN}[OK] $1${NC}"; }
print_warn() { echo -e "${YELLOW}[!] $1${NC}"; }
print_error() { echo -e "${RED}[X] $1${NC}"; }

# --- Header ---
echo "========================================"
echo "      DIVINETOOLS INSTALLER v2.1"
echo "========================================"

# --- 1. Environment ---
if [ -z "$TERMUX_VERSION" ]; then
    print_warn "Not in Termux!"
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    print_ok "Termux Detected"
    termux-setup-storage
fi

# --- 2. Dependencies ---
print_info "Updating system..."
pkg update -y >/dev/null 2>&1 && pkg upgrade -y >/dev/null 2>&1

PKGS=("lua53" "luarocks" "python" "tsu" "android-tools" "jq" "make" "clang" "busybox")

print_info "Installing packages..."
for pkg in "${PKGS[@]}"; do
    if pkg install -y "$pkg" >/dev/null 2>&1; then
        print_ok "$pkg installed"
    else
        print_error "Failed: $pkg"
    fi
done

# --- 3. Lua Fix ---
print_info "Configuring Lua..."
if [ -d "$PREFIX/include/lua5.3" ]; then
    export C_INCLUDE_PATH=$PREFIX/include/lua5.3:$C_INCLUDE_PATH
fi

if luarocks --lua-version=5.3 install lua-cjson >/dev/null 2>&1; then
    print_ok "lua-cjson installed"
else
    print_error "lua-cjson failed"
fi

# --- 4. Root Check ---
print_info "Checking Root..."
if su -c "id" >/dev/null 2>&1; then
    print_ok "Root Access Granted"
else
    print_error "Root NOT Found"
    print_warn "Optimizers disabled"
fi

# --- 5. Config & Dirs ---
print_info "Creating dirs..."
mkdir -p config logs src
chmod +x *.sh 2>/dev/null

if [ ! -f "config/config.json" ]; then
    print_info "Creating default config..."
    cat > config/config.json <<EOF
{
    "project_name": "DivineTools",
    "version": "2.0",
    "package_name": "com.roblox.client",
    "settings": {
        "enable_swap": true,
        "swap_size_mb": 2048
    }
}
EOF
    print_ok "Config generated"
else
    print_ok "Config exists"
fi

# --- Finish ---
echo ""
echo -e "${GREEN}========================================"
echo "         INSTALL COMPLETE"
echo -e "========================================${NC}"
echo -e "${YELLOW}bash run.sh${NC}"