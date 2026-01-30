#!/bin/bash
# DIVINE TOOLS - ENGINE & DASHBOARD
# Version 4.0

# --- COLORS ---
C='\033[1;36m' # Cyan
G='\033[1;32m' # Green
R='\033[1;31m' # Red
Y='\033[1;33m' # Yellow
W='\033[1;37m' # White
N='\033[0m'    # Reset

CONFIG_FILE="config/config.json"

# --- UTILS ---
print_info() { echo -e "${C}[INFO] $1${N}"; }
print_ok() { echo -e "${G}[OK] $1${N}"; }
print_err() { echo -e "${R}[ERR] $1${N}"; }

# --- CHECK CONFIG ---
if [ ! -f "$CONFIG_FILE" ]; then
    print_err "Config file not found: $CONFIG_FILE"
    exit 1
fi

# --- LOAD CONFIG ---
# Using jq to extract values. Defaulting to safe values if keys are missing.
ENABLE_SWAP=$(jq -r '.settings.enable_swap // false' "$CONFIG_FILE")
LAUNCH_DELAY=$(jq -r '.timing.launch_delay // 5' "$CONFIG_FILE")
PS_MODE=$(jq -r '.private_servers.mode // "same"' "$CONFIG_FILE")
PS_URL_ALL=$(jq -r '.private_servers.url // ""' "$CONFIG_FILE")

# Read packages into an array
mapfile -t PACKAGES < <(jq -r '.packages[] // empty' "$CONFIG_FILE")

if [ ${#PACKAGES[@]} -eq 0 ]; then
    print_err "No packages found in config!"
    exit 1
fi

# --- 1. SYSTEM PREP ---
setup_system() {
    print_info "Preparing system..."
    
    # SWAP MANAGER
    if [ "$ENABLE_SWAP" == "true" ]; then
        print_info "Checking Swap configuration..."
        # Check/Create Swap
        if ! su -c "[ -f /data/swapfile ]"; then
            print_info "Creating 2GB Swap File (Please wait)..."
            su -c "dd if=/dev/zero of=/data/swapfile bs=1M count=2048" >/dev/null 2>&1
            su -c "mkswap /data/swapfile" >/dev/null 2>&1
            su -c "chmod 600 /data/swapfile" >/dev/null 2>&1
            print_ok "Swap file created."
        fi
        
        # Enable Swap
        if ! su -c "grep -q '/data/swapfile' /proc/swaps"; then
            su -c "swapon /data/swapfile" >/dev/null 2>&1
            su -c "echo 100 > /proc/sys/vm/swappiness" >/dev/null 2>&1
            print_ok "Swap Enabled."
        else
            print_ok "Swap already active."
        fi
    else
        print_info "Swap disabled in config."
    fi

    # CPU BOOST
    print_info "Applying CPU Boost..."
    # Loop through all cpu cores
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        su -c "echo performance > $cpu" 2>/dev/null
    done
    print_ok "CPU Governor set to Performance."
}

# --- 2. LAUNCHER ---
launch_accounts() {
    print_info "Launching accounts..."
    
    local idx=0
    for pkg in "${PACKAGES[@]}"; do
        ((idx++))
        print_info "[$idx/${#PACKAGES[@]}] Starting $pkg..."
        
        # Determine Link
        local link=""
        if [ "$PS_MODE" == "same" ]; then
            link="$PS_URL_ALL"
        else
            # Extract specific url for package
            link=$(jq -r --arg p "$pkg" '.private_servers.urls[$p] // ""' "$CONFIG_FILE")
        fi
        
        # Force Stop
        su -c "am force-stop $pkg" >/dev/null 2>&1
        
        # Launch
        if [ -n "$link" ] && [ "$link" != "null" ]; then
            # Launch with View Intent (Private Server)
            su -c "am start -a android.intent.action.VIEW -d \"$link\" -p $pkg" >/dev/null 2>&1
        else
            # Fallback Launch (Standard Activity)
            su -c "am start -n $pkg/com.roblox.client.Activity" >/dev/null 2>&1
        fi
        
        sleep "$LAUNCH_DELAY"
    done
}

# --- 3. DASHBOARD ---
draw_dashboard() {
    while true; do
        clear
        # HEADER (Kaeru Style)
        echo -e "${C}"
        echo "  ██████╗ ██╗██╗   ██╗██╗███╗   ██╗███████╗"
        echo "  ██╔══██╗██║██║   ██║██║████╗  ██║██╔════╝"
        echo "  ██║  ██║██║██║   ██║██║██╔██╗ ██║█████╗  "
        echo "  ██║  ██║██║╚██╗ ██╔╝██║██║╚██╗██║██╔══╝  "
        echo "  ██████╔╝██║ ╚████╔╝ ██║██║ ╚████║███████╗"
        echo "  ╚═════╝ ╚═╝  ╚═══╝  ╚═╝╚═╝  ╚═══╝╚══════╝"
        echo -e "       ${W}ENGINE & DASHBOARD${N}"
        echo ""

        # SYSTEM STATS
        FREE_RAM=$(free -m | awk '/Mem:/ {print $4}')
        echo -e "${W}System Memory: ${G}${FREE_RAM} MB Free${N}"
        echo ""

        # TABLE
        echo -e "${C}+----+----------------------+--------+${N}"
        echo -e "${C}| NO | PACKAGE/CLONE        | STATUS |${N}"
        echo -e "${C}+----+----------------------+--------+${N}"

        local i=1
        for pkg in "${PACKAGES[@]}"; do
            # Clone Name (Last part)
            local clone_name="${pkg##*.}"
            # Truncate to 20 chars
            if [ ${#clone_name} -gt 20 ]; then clone_name="${clone_name:0:17}..."; fi
            
            # Check Status
            local status_text="[OFF]"
            local status_color="${R}"
            if pgrep -f "$pkg" >/dev/null; then
                status_text="[ON]"
                status_color="${G}"
            fi
            
            # Format: | NO | CLONE | STATUS |
            printf "${C}|${N} %-2d ${C}|${N} %-20s ${C}|${N} ${status_color}%-6s${N} ${C}|${N}\n" "$i" "$clone_name" "$status_text"
            
            ((i++))
        done
        echo -e "${C}+----+----------------------+--------+${N}"
        echo -e "\n${Y}Refreshing in 5s... (CTRL+C to Stop)${N}"
        
        sleep 5
    done
}

# --- EXECUTION ---
setup_system
launch_accounts
draw_dashboard