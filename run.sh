#!/bin/bash
# DIVINE TOOLS - ENGINE & DASHBOARD
# Version 4.5 (Auto-Grid & Identity)

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

# --- UTILS: SCREEN & GRID ---
get_screen_size() {
    # Default to 720x1280 if detection fails
    SCREEN_WIDTH=720
    SCREEN_HEIGHT=1280
    
    if command -v wm >/dev/null; then
        local size_str=$(wm size | grep "Physical size" | awk '{print $3}')
        if [[ "$size_str" =~ ([0-9]+)x([0-9]+) ]]; then
            SCREEN_WIDTH=${BASH_REMATCH[1]}
            SCREEN_HEIGHT=${BASH_REMATCH[2]}
        fi
    fi
}

calculate_bounds() {
    local idx=$1 # 0-based index
    local total=$2
    local w=$SCREEN_WIDTH
    local h=$SCREEN_HEIGHT
    
    # Determine Grid Layout based on Total Accounts
    local cols=1
    local rows=1
    
    if [ "$total" -le 2 ]; then
        cols=1; rows=2
    elif [ "$total" -le 4 ]; then
        cols=2; rows=2
    elif [ "$total" -le 6 ]; then
        cols=2; rows=3
    else
        cols=3; rows=3
    fi
    
    # Calculate Cell Size
    local cell_w=$((w / cols))
    local cell_h=$((h / rows))
    
    # Calculate Position
    local col_idx=$((idx % cols))
    local row_idx=$((idx / cols))
    
    local left=$((col_idx * cell_w))
    local top=$((row_idx * cell_h))
    local right=$((left + cell_w))
    local bottom=$((top + cell_h))
    
    echo "${left},${top},${right},${bottom}"
}

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
    get_screen_size
    echo -e "${C}[*] Screen: ${SCREEN_WIDTH}x${SCREEN_HEIGHT} | Grid Mode${N}"
    
    local idx=0
    for pkg in "${PACKAGES[@]}"; do
        # Get Link
        local link=""
        if [ "$PS_MODE" == "same" ]; then
            link="$PS_URL_ALL"
        else
            link=$(jq -r --arg p "$pkg" '.private_servers.urls[$p] // ""' "$CONF_FILE")
        fi
        
        # Calculate Bounds
        local bounds=$(calculate_bounds $idx $TOTAL)
        
        # Kill App
        su -c "am force-stop $pkg" >/dev/null 2>&1
        
        # Launch Freeform with Bounds
        local cmd="am start -n $pkg/com.roblox.client.Activity --windowingMode 5 --bounds $bounds"
        if [ -n "$link" ] && [ "$link" != "null" ]; then
             cmd="$cmd -a android.intent.action.VIEW -d \"$link\""
        fi
        
        su -c "$cmd" >/dev/null 2>&1
        
        ((idx++))
        sleep "$DELAY"
    done
}

# --- UI: DRAW DASHBOARD ---
draw_dashboard() {
    while true; do
        clear
        # 1. HEADER (Compact Block Style - Max 40 chars)
        echo -e "${C}"
        echo "█▀▄ █ █ █ █▄ █ █▀"
        echo "█▄▀ █ ▀▄▀ █ ▀█ █▄▄"
        echo -e "${N}"
        echo -e "${C}=== PREMIUM FARM MANAGER ===${N}"
        echo ""
        
        # 2. SYSTEM & MEMORY BOXES
        # Get Memory Info
        local mem_info=$(free -m | awk '/Mem:/ {print $2,$4}') # Total Free
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
        
        # Draw Boxes (Width ~40)
        echo -e "${C}+------------------+-------------------+${N}"
        echo -e "${C}|${W} SYSTEM           ${C}|${W} MEMORY            ${C}|${N}"
        printf "${C}|${W} Active: %-9s${C}|${W} Free: %-4sMB %3s%%${C}|${N}\n" "$online_cnt/$TOTAL" "$free_mem" "$mem_pct"
        echo -e "${C}+------------------+-------------------+${N}"

        # 3. THE TABLE (No Headers)
        for pkg in "${PACKAGES[@]}"; do
            # Truncate package name (last 15 chars)
            local display_name="${pkg}"
            if [ ${#display_name} -gt 15 ]; then
                display_name="...${display_name: -15}"
            fi
            
            # Check Status
            local status_text="Offline"
            local status_color="${R}"
            if pgrep -f "$pkg" >/dev/null; then
                status_text="Online "
                status_color="${G}"
            fi
            
            # Format: | [pkg] | [Status] |
            printf "${C}|${W} %-18s ${C}|${N} ${status_color}%-9s${N} ${C}|${N}\n" "$display_name" "$status_text"
        done
        echo -e "${C}+--------------------------------------+${N}"
        echo -e "\n${Y}Refreshing in 3s...${N}"
        
        sleep 3
    done
}

# --- MAIN EXECUTION ---
setup_environment
launch_sequence
draw_dashboard