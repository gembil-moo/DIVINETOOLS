#!/bin/bash
# DIVINE TOOLS - ENGINE & DASHBOARD
# Version 6.0 (Ultimate Optimization)

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
ENABLE_BOOST=$(jq -r '.settings.enable_cpu_boost // false' "$CONF_FILE")
MASKING=$(jq -r '.settings.masking // false' "$CONF_FILE")
DELAY=$(jq -r '.timing.launch_delay // 30' "$CONF_FILE")
PS_MODE=$(jq -r '.private_servers.mode // "same"' "$CONF_FILE")
PS_URL_ALL=$(jq -r '.private_servers.url // ""' "$CONF_FILE")

# Load packages into array
mapfile -t PACKAGES < <(jq -r '.packages[] // empty' "$CONF_FILE")
TOTAL=${#PACKAGES[@]}

if [ "$TOTAL" -eq 0 ]; then
    echo -e "${R}[ERROR] No packages found in config!${N}"
    exit 1
fi

# --- UTILS ---
header() {
    clear
    echo -e "${C}"
    echo "   ___  _____    _(_)___  ___"
    echo "  / _ \/  _/ |  / / / _ \/ _ \\"
    echo " / // // / | | / / / // /  __/"
    echo "/____/___/ |___/_/_/_//_/\\___/"
    echo -e "${N}"
    echo -e "${C}=== DIVINE TOOLS v5.4 ===${N}"
    echo ""
}

mask_string() {
    local str=$1
    if [ "$MASKING" == "true" ]; then
        # Masking: com.roblox.client -> com...ient
        if [ ${#str} -gt 10 ]; then
            echo "${str:0:3}...${str: -4}"
        else
            echo "$str"
        fi
    else
        # Truncate if too long
        if [ ${#str} -gt 18 ]; then
            echo "${str:0:15}..."
        else
            echo "$str"
        fi
    fi
}

# --- SYSTEM OPTIMIZATION ---
optimize_system() {
    echo -e "${C}[*] Applying Ultimate 5-Step Optimization...${N}"
    
    # 1. CPU Governor (Performance)
    echo -e "${Y}    [1/5] CPU Governor -> Performance${N}"
    if [ "$ENABLE_BOOST" == "true" ]; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            su -c "echo performance > $cpu" >/dev/null 2>&1
        done
    fi

    # 2. RAM Cleaning (Kill & Flush & Swap)
    echo -e "${Y}    [2/5] RAM Cleaning & Swap${N}"
    if command -v su >/dev/null; then
        su -c "am kill-all" >/dev/null 2>&1
        su -c "sync; echo 3 > /proc/sys/vm/drop_caches" >/dev/null 2>&1
    fi

    if [ "$SWAP" == "true" ]; then
        if ! su -c "[ -f /data/swapfile ]"; then
            echo -e "${W}          Creating 2GB Swap...${N}"
            su -c "dd if=/dev/zero of=/data/swapfile bs=1M count=2048" >/dev/null 2>&1
            su -c "mkswap /data/swapfile" >/dev/null 2>&1
            su -c "chmod 600 /data/swapfile" >/dev/null 2>&1
        fi
        su -c "swapon /data/swapfile" >/dev/null 2>&1
    fi

    # 3. Android Settings (Animation & Touch)
    echo -e "${Y}    [3/5] Disabling Animations & Tuning Touch${N}"
    su -c "settings put global window_animation_scale 0" >/dev/null 2>&1
    su -c "settings put global transition_animation_scale 0" >/dev/null 2>&1
    su -c "settings put global animator_duration_scale 0" >/dev/null 2>&1
    su -c "settings put secure long_press_timeout 250" >/dev/null 2>&1
    su -c "settings put system pointer_speed 7" >/dev/null 2>&1

    # 4. Thermal Throttling Disable
    echo -e "${Y}    [4/5] Stopping Thermal Services${N}"
    su -c "stop thermald" >/dev/null 2>&1
    su -c "stop thermal-engine" >/dev/null 2>&1

    # 5. Build.prop / GPU Tweaks (Runtime)
    echo -e "${Y}    [5/5] Forcing GPU Rendering & Low RAM Mode${N}"
    su -c "setprop debug.sf.hw 1" >/dev/null 2>&1
    su -c "setprop video.accelerate.hw 1" >/dev/null 2>&1
    su -c "setprop debug.egl.hw 1" >/dev/null 2>&1
    su -c "setprop ro.config.low_ram true" >/dev/null 2>&1

    echo -e "${G}[OK] System Optimized.${N}"
    sleep 1
}

# --- LAUNCHER LOGIC ---
launch_sequence() {
    header
    optimize_system
    
    header
    echo -e "${C}[*] Launching $TOTAL Accounts...${N}"
    
    local idx=0
    for pkg in "${PACKAGES[@]}"; do
        ((idx++))
        echo -e "${W}[$idx/$TOTAL] Starting $pkg...${N}"

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
        header
        
        # 2. SYSTEM INFO
        # Get Memory Info
        local mem_info=$(free -m | awk '/Mem:/ {print $2,$4}')
        read -r total_mem free_mem <<< "$mem_info"
        
        # Calculate Percentage
        local mem_pct=0
        if [ "$total_mem" -gt 0 ]; then
            mem_pct=$(awk "BEGIN {printf \"%.0f\", ($free_mem/$total_mem)*100}")
        fi

        # Count Online
        local online_cnt=0
        for pkg in "${PACKAGES[@]}"; do
            if pgrep -f "$pkg" >/dev/null; then ((online_cnt++)); fi
        done
        
        # KAERU STYLE DASHBOARD (Max Width 40)
        # +--------------------------------------+
        # | PACKAGE             | STATUS         |
        # +---------------------+----------------+
        # | System              | Checking [x/y] |
        # | Memory              | Free: xxxxMB   |
        # +---------------------+----------------+
        # | com...dodj          | [Online]       |
        # +---------------------+----------------+

        echo -e "${C}+-----------------------+----------------+${N}"
        echo -e "${C}| PACKAGE               | STATUS         |${N}"
        echo -e "${C}+-----------------------+----------------+${N}"
        
        # Info Rows
        printf "${C}|${W} System                ${C}|${W} Checking [%s/%s] ${C}|${N}\n" "$online_cnt" "$TOTAL"
        printf "${C}|${W} Memory                ${C}|${W} Free: %4sMB (%s%%)${C}|${N}\n" "$free_mem" "$mem_pct"
        echo -e "${C}+-----------------------+----------------+${N}"

        # Data Rows
        for pkg in "${PACKAGES[@]}"; do
            local display_name=$(mask_string "$pkg")
            
            # Check Status
            local status="${R}Offline${N}"
            if pgrep -f "$pkg" >/dev/null; then
                status="${G}Online ${N}"
            fi
            
            # Fixed width formatting: Package (21 chars), Status (14 chars visual space)
            printf "${C}|${W} %-21s ${C}|${N} %-14b ${C}|${N}\n" "$display_name" "$status"
        done
        echo -e "${C}+-----------------------+----------------+${N}"
        echo -e "\n${Y}Refreshing in 5s...${N}"
        
        sleep 5
    done
}

# --- MAIN EXECUTION ---
launch_sequence
draw_dashboard