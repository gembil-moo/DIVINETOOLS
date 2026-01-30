#!/bin/bash
# DIVINE TOOLS - ENGINE & DASHBOARD
# Version 4.3 (Kaeru Style)

# --- COLORS ---
C='\033[1;36m' # Cyan
G='\033[1;32m' # Green
R='\033[1;31m' # Red
W='\033[1;37m' # White
N='\033[0m'    # Reset
Y='\033[1;33m' # Yellow

CONF_FILE="config/config.json"

# --- CHECK CONFIG ---
if [ ! -f "$CONF_FILE" ]; then
    echo -e "${R}[ERROR] Config file not found!${N}"
    exit 1
fi

# --- LOAD SETTINGS ---
SWAP=$(jq -r '.settings.enable_swap // false' "$CONF_FILE")
DELAY=$(jq -r '.timing.launch_delay // 5' "$CONF_FILE")
PS_MODE=$(jq -r '.private_servers.mode // "same"' "$CONF_FILE")
PS_URL_ALL=$(jq -r '.private_servers.url // ""' "$CONF_FILE")

# Load packages into array
mapfile -t PACKAGES < <(jq -r '.packages[] // empty' "$CONF_FILE")
TOTAL=${#PACKAGES[@]}

if [ "$TOTAL" -eq 0 ]; then
    echo -e "${R}[ERROR] No packages found in config!${N}"
    exit 1
fi

# --- SYSTEM OPTIMIZATION ---
setup_environment() {
    # 1. Swap Manager
    if [ "$SWAP" == "true" ]; then
        if ! su -c "[ -f /data/swapfile ]"; then
            su -c "dd if=/dev/zero of=/data/swapfile bs=1M count=2048" >/dev/null 2>&1
            su -c "mkswap /data/swapfile" >/dev/null 2>&1
            su -c "chmod 600 /data/swapfile" >/dev/null 2>&1
        fi
        su -c "swapon /data/swapfile" >/dev/null 2>&1
    fi

    # 2. CPU Boost
    su -c "sync; echo 3 > /proc/sys/vm/drop_caches" >/dev/null 2>&1
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        su -c "echo performance > $cpu" >/dev/null 2>&1
    done
}

# --- LAUNCHER LOGIC ---
launch_sequence() {
    echo -e "${C}[*] Launching $TOTAL Accounts...${N}"
    
    local idx=0
    for pkg in "${PACKAGES[@]}"; do
        ((idx++))
        
        # Get Link
        local link=""
        if [ "$PS_MODE" == "same" ]; then
            link="$PS_URL_ALL"
        else
            link=$(jq -r --arg p "$pkg" '.private_servers.urls[$p] // ""' "$CONF_FILE")
        fi
        
        # Kill App
        su -c "am force-stop $pkg" >/dev/null 2>&1
        
        # Launch Freeform (Window Mode 5)
        local cmd="am start -n $pkg/com.roblox.client.Activity --windowingMode 5"
        if [ -n "$link" ] && [ "$link" != "null" ]; then
             cmd="$cmd -a android.intent.action.VIEW -d \"$link\""
        fi
        
        su -c "$cmd" >/dev/null 2>&1
        
        sleep "$DELAY"
    done
}

# --- UI: DRAW DASHBOARD ---
draw_dashboard() {
    while true; do
        clear
        # 1. HEADER (Kaeru Style)
        echo -e "${C}"
        echo "  ██████╗ ██╗██╗   ██╗██╗███╗   ██╗███████╗"
        echo "  ██╔══██╗██║██║   ██║██║████╗  ██║██╔════╝"
        echo "  ██║  ██║██║██║   ██║██║██╔██╗ ██║█████╗  "
        echo "  ██║  ██║██║╚██╗ ██╔╝██║██║╚██╗██║██╔══╝  "
        echo "  ██████╔╝██║ ╚████╔╝ ██║██║ ╚████║███████╗"
        echo "  ╚═════╝ ╚═╝  ╚═══╝  ╚═╝╚═╝  ╚═══╝╚══════╝"
        echo -e "       ${W}PREMIUM AUTOMATION TOOL${N}"
        echo ""

        # 2. SYSTEM INFO
        FREE_RAM=$(free -m | awk '/Mem:/ {print $4}')
        echo -e "${W}System Memory: ${G}${FREE_RAM} MB Free${N}"
        echo ""
        
        # 3. THE TABLE
        echo -e "${C}+----+----------------------+--------+${N}"
        echo -e "${C}| NO | PACKAGE/CLONE        | STATUS |${N}"
        echo -e "${C}+----+----------------------+--------+${N}"

        local i=1
        for pkg in "${PACKAGES[@]}"; do
            # Clone Name (Last part)
            local clone_name="${pkg##*.}"
            # Truncate to 20 chars to fit column width 22 (approx)
            if [ ${#clone_name} -gt 20 ]; then clone_name="${clone_name:0:17}..."; fi
            
            # Check Status
            local status_text="[OFF]"
            local status_color="${R}"
            if pgrep -f "$pkg" >/dev/null; then
                status_text="[ON]"
                status_color="${G}"
            fi
            
            # Format: | NO | CLONE | STATUS |
            # Widths: 2, 20, 6 (plus padding)
            printf "${C}|${N} %-2d ${C}|${N} %-20s ${C}|${N} ${status_color}%-6s${N} ${C}|${N}\n" "$i" "$clone_name" "$status_text"
            
            ((i++))
        done
        echo -e "${C}+----+----------------------+--------+${N}"
        echo -e "\n${Y}Refreshing in 5s... (CTRL+C to Stop)${N}"
        
        sleep 5
    done
}

# --- MAIN EXECUTION ---
setup_environment
launch_sequence
draw_dashboard