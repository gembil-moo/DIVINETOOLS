#!/bin/bash
# DIVINETOOLS Installer - ANTI FREEZE VERSION

echo "[*] Setting up DIVINETOOLS environment..."
echo "[*] Working directory: $(pwd)"

# FUNGSI PRINT AMAN (TANPA WARNA)
print_info() { echo "[*] $1"; }
print_success() { echo "[+] $1"; }
print_warn() { echo "[!] $1"; }
print_error() { echo "[ERROR] $1"; }

# DISABLE SEMUA WARNA DAN ANSI CODES
export TERM=xterm-mono

# Check if running in Termux
if [ -z "$TERMUX_VERSION" ]; then
    print_warn "This script is designed for Termux"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check dependencies
print_info "Checking dependencies..."
for cmd in curl wget git; do
    if ! command -v $cmd &> /dev/null; then
        print_warn "Installing $cmd..."
        pkg install -y $cmd 2>/dev/null || apt-get install -y $cmd 2>/dev/null
    fi
done

# Request storage permission (Termux)
if [ -n "$TERMUX_VERSION" ]; then
    print_info "Requesting storage access..."
    termux-setup-storage
fi

# Update system
print_info "Updating package lists..."
pkg update -y && pkg upgrade -y

# Install system packages
print_info "Installing required packages..."
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
print_info "Installing Lua modules..."
luarocks install lua-cjson 2>/dev/null || print_warn "Failed to install lua-cjson"
luarocks install luasocket 2>/dev/null || print_warn "Failed to install luasocket"

# Install Python libraries
print_info "Installing Python packages..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt 2>/dev/null || print_warn "Failed to install Python packages"
else
    print_warn "requirements.txt not found"
    pip install pyfiglet rich 2>/dev/null
fi

# Create necessary directories
print_info "Creating directory structure..."
mkdir -p config logs scripts/autoexec scripts/divine src/modules

# Set permissions
print_info "Setting permissions..."
[ -f "run.sh" ] && chmod +x run.sh && print_success "run.sh permissions set"
[ -f "install.sh" ] && chmod +x install.sh && print_success "install.sh permissions set"

# Check for root access
if su -c "echo 'Root check'" &>/dev/null; then
    print_success "Root access available"
else
    print_warn "Root access not available. Some features may be limited."
fi

# Create example config if not exists
if [ ! -f "config/config.json" ] && [ -f "config.example.json" ]; then
    cp config.example.json config/config.json
    print_success "Created default config"
elif [ ! -f "config/config.json" ]; then
    print_info "Creating minimal config..."
    mkdir -p config
    cat > config/config.json << 'CONFIG_EOF'
{
    "version": "2.0.0",
    "first_run": true,
    "log_level": "info"
}
CONFIG_EOF
    print_success "Created minimal config"
fi

# FINAL OUTPUT - PLAIN TEXT, NO FORMATTING
echo ""
print_success "Installation complete!"
print_success "Run with: ./run.sh"
echo ""
echo "Next steps:"
echo "1. Edit config/config.json if needed"
echo "2. Run: ./run.sh"
echo "3. Select 'First Configuration' in menu"
echo ""
print_info "Current directory: $(pwd)"
print_info "Files: $(ls | tr '\n' ' ')"