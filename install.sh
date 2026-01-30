#!/bin/bash

# DIVINETOOLS Installer - Professional Version

# --- 1. UI & Logging ---
# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
print_ok() { echo -e "${GREEN}[OK] $1${NC}"; }
print_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
print_error() { echo -e "${RED}[ERROR] $1${NC}"; }

echo -e "${BLUE}"
echo "========================================"
echo "       DIVINETOOLS INSTALLER v2.0       "
echo "========================================"
echo -e "${NC}"

# --- 2. Environment Checks ---
if [ -z "$TERMUX_VERSION" ]; then
    print_warn "You are not running inside Termux!"
    read -p "Do you want to continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Installation aborted."
        exit 1
    fi
else
    print_info "Termux environment detected."
    print_info "Requesting storage access..."
    termux-setup-storage
    sleep 2
fi

# --- 3. System Update & Dependencies ---
print_info "Updating system packages..."
pkg update -y && pkg upgrade -y

DEPENDENCIES=("lua53" "luarocks" "python" "make" "clang" "busybox" "coreutils" "ncurses-utils" "figlet")
CRITICAL_DEPENDENCIES=("tsu" "android-tools" "jq")

print_info "Installing dependencies..."

# Install Standard Dependencies
for pkg in "${DEPENDENCIES[@]}"; do
    print_info "Installing $pkg..."
    pkg install -y "$pkg" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_ok "$pkg installed."
    else
        print_warn "Failed to install $pkg. Attempting to continue..."
    fi
done

# Install Critical Dependencies
for pkg in "${CRITICAL_DEPENDENCIES[@]}"; do
    print_info "Installing CRITICAL package: $pkg..."
    pkg install -y "$pkg" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        print_error "Critical dependency '$pkg' failed to install!"
        exit 1
    else
        print_ok "$pkg installed."
    fi
done

# --- 4. Lua Module Fix (Termux Fix) ---
print_info "Configuring Lua environment..."

# Export include path for Lua 5.3 headers
if [ -d "$PREFIX/include/lua5.3" ]; then
    export C_INCLUDE_PATH=$PREFIX/include/lua5.3:$C_INCLUDE_PATH
    print_ok "Exported C_INCLUDE_PATH for Lua 5.3"
else
    print_warn "Lua 5.3 include directory not found. Compilation might fail."
fi

# Install Lua Modules
print_info "Installing Lua modules via LuaRocks..."
luarocks --lua-version=5.3 install lua-cjson
if [ $? -eq 0 ]; then print_ok "lua-cjson installed."; else print_warn "lua-cjson failed."; fi

luarocks --lua-version=5.3 install luasocket
if [ $? -eq 0 ]; then print_ok "luasocket installed."; else print_warn "luasocket failed."; fi

# --- 5. Python Setup ---
print_info "Setting up Python environment..."
if [ -f "requirements.txt" ]; then
    print_info "Installing from requirements.txt..."
    pip install -r requirements.txt
else
    print_info "requirements.txt not found. Installing default libraries..."
    pip install pyfiglet rich
fi

# --- 6. Project Structure ---
print_info "Creating project directories..."
mkdir -p config logs src/modules workspace
print_ok "Directories created: config, logs, src/modules, workspace"

print_info "Setting file permissions..."
chmod +x *.sh 2>/dev/null
print_ok "Executable permissions set for .sh files."

# --- 7. Root Verification ---
print_info "Checking Root Access..."
if command -v tsu >/dev/null 2>&1 && tsu -c true > /dev/null 2>&1; then
    print_ok "Root access granted."
else
    print_warn "ROOT ACCESS NOT DETECTED!"
    print_warn "Device Optimizer features (Swap, CPU Boost, Auto-Kill) will NOT work."
    print_warn "The tool will run in Limited Mode."
fi

# --- 8. Configuration Logic ---
print_info "Checking configuration..."
if [ -f "config/config.json" ]; then
    print_ok "Config file exists."
elif [ -f "config.example.json" ]; then
    print_info "Copying example config..."
    cp config.example.json config/config.json
    print_ok "Config created from example."
else
    print_warn "No config found. Generating minimal config..."
    cat > config/config.json <<EOF
{
    "version": "2.0",
    "package_name": "com.roblox.client",
    "swap_size_gb": 2,
    "private_server": ""
}
EOF
    print_ok "Minimal config.json generated."
fi

# --- 9. Final Output ---
echo ""
echo -e "${GREEN}========================================"
echo -e "      INSTALLATION SUCCESSFUL!          "
echo -e "========================================${NC}"
echo ""
echo -e "To start the tool, run:"
echo -e "${YELLOW}bash run.sh${NC}"
echo ""