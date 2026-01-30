#!/bin/bash

# DIVINETOOLS Runner - Professional Version

# --- 1. UI & Logging ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
print_ok() { echo -e "${GREEN}[OK] $1${NC}"; }
print_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
print_error() { echo -e "${RED}[ERROR] $1${NC}"; }

# --- 2. Configuration Loading ---
CONFIG_DIR="config"
CONFIG_FILE="$CONFIG_DIR/config.json"
EXAMPLE_CONFIG="config.example.json"

print_info "Loading configuration..."

# Check dependencies
if ! command -v jq &> /dev/null; then
    print_error "jq is not installed. Please run install.sh first."
    exit 1
fi

# Ensure config exists
if [ ! -f "$CONFIG_FILE" ]; then
    if [ -f "$EXAMPLE_CONFIG" ]; then
        print_warn "Config not found. Creating from example..."
        mkdir -p "$CONFIG_DIR"
        cp "$EXAMPLE_CONFIG" "$CONFIG_FILE"
        print_ok "Config created."
    else
        print_error "Config file not found and example missing!"
        exit 1
    fi
fi

# Parse Config using jq
PACKAGE_NAME=$(jq -r '.package_name // "com.roblox.client"' "$CONFIG_FILE")
ACTIVITY_NAME=$(jq -r '.activity_name // "com.roblox.client.Activity"' "$CONFIG_FILE")
PRIVATE_SERVER=$(jq -r '.private_server_link // ""' "$CONFIG_FILE")
ENABLE_SWAP=$(jq -r '.settings.enable_swap // false' "$CONFIG_FILE")
SWAP_SIZE_MB=$(jq -r '.settings.swap_size_mb // 2048' "$CONFIG_FILE")
ENABLE_BOOST=$(jq -r '.settings.enable_cpu_boost // false' "$CONFIG_FILE")
REJOIN_DELAY=$(jq -r '.settings.rejoin_delay_seconds // 1800' "$CONFIG_FILE")

print_ok "Target Package: $PACKAGE_NAME"
print_ok "Rejoin Delay: ${REJOIN_DELAY}s"

# --- 3. Feature: Virtual RAM (Swap Manager) ---
setup_swap() {
    if [ "$ENABLE_SWAP" != "true" ]; then return; fi

    print_info "Checking Swap configuration..."
    
    # Check if swap file exists
    if ! su -c "[ -f /data/swapfile ]"; then
        print_warn "Creating ${SWAP_SIZE_MB}MB Swap File (This may take a moment)..."
        su -c "dd if=/dev/zero of=/data/swapfile bs=1M count=$SWAP_SIZE_MB"
        su -c "mkswap /data/swapfile"
        su -c "chmod 600 /data/swapfile"
        print_ok "Swap file created."
    fi

    # Check if active
    if ! su -c "grep -q '/data/swapfile' /proc/swaps"; then
        print_info "Activating Swap..."
        su -c "swapon /data/swapfile"
        su -c "echo 100 > /proc/sys/vm/swappiness"
        print_ok "Swap activated (Swappiness: 100)."
    else
        print_ok "Swap is already active."
    fi
}

# --- 4. Feature: Device Optimization ---
optimize_device() {
    if [ "$ENABLE_BOOST" != "true" ]; then return; fi

    print_info "Optimizing device performance..."

    # Clear RAM Cache
    su -c "sync; echo 3 > /proc/sys/vm/drop_caches"
    
    # CPU Governor -> Performance
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        su -c "echo performance > $cpu" 2>/dev/null
    done
    
    # Aggressive LMK (Low Memory Killer) for 4GB+ RAM
    # Values: 72MB, 90MB, 108MB, 126MB, 216MB, 315MB
    local lmk_values="18432,23040,27648,32256,55296,80640"
    su -c "echo '$lmk_values' > /sys/module/lowmemorykiller/parameters/minfree" 2>/dev/null
    
    print_ok "RAM cleared & CPU boosted."
}

# --- 5. Feature: Direct Launcher ---
launch_roblox() {
    print_info "Launching Roblox..."
    
    # Force Stop
    su -c "am force-stop $PACKAGE_NAME"
    sleep 1
    
    # Construct Command
    local cmd="am start -n $PACKAGE_NAME/$ACTIVITY_NAME"
    if [ -n "$PRIVATE_SERVER" ] && [ "$PRIVATE_SERVER" != "null" ]; then
        cmd="$cmd -a android.intent.action.VIEW -d \"$PRIVATE_SERVER\""
    fi
    
    # Execute
    su -c "$cmd" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_ok "Game launched successfully!"
    else
        print_error "Failed to launch. Check Package Name in config."
    fi
}

# --- 6. Main Loop ---
countdown() {
    local seconds=$1
    while [ $seconds -gt 0 ]; do
        echo -ne "${YELLOW}\r[*] Rejoining in $seconds seconds... ${NC}"
        sleep 1
        : $((seconds--))
    done
    echo -e "\n"
}

main() {
    # Initial Setup
    setup_swap
    
    while true; do
        echo -e "${BLUE}========================================${NC}"
        echo -e "      ${GREEN}DIVINETOOLS AUTO-FARM${NC}            "
        echo -e "${BLUE}========================================${NC}"
        echo "Time: $(date +%H:%M:%S)"
        
        optimize_device
        launch_roblox
        
        print_info "Session started. Waiting for next cycle..."
        countdown $REJOIN_DELAY
    done
}

# Start
main