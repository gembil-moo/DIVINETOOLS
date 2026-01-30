#!/bin/bash
# DIVINE TOOLS - AUTOMATION
# Version 7.5 (Manual Menu Fix)

# Colors
C='\033[1;36m' # Cyan
G='\033[1;32m' # Green
R='\033[1;31m' # Red
W='\033[1;37m' # White
N='\033[0m'    # Reset

CONFIG_FILE="config/config.json"
mkdir -p config

# Initialize Config if missing
if ! command -v jq &> /dev/null; then
    echo -e "${R}[!] jq is not installed. Please run install.sh${N}"
    exit 1
fi

# Initialize Config if missing
if [ ! -f "$CONFIG_FILE" ]; then
    echo '{
        "packages": [],
        "private_servers": {"mode": "same", "url": "", "urls": {}},
        "webhook": {"enabled": false},
        "timing": {"launch_delay": 30, "reset_interval": 0},
        "settings": {"masking": false, "enable_swap": true, "enable_cpu_boost": true}
    }' > "$CONFIG_FILE"
fi

# Header
header() {
    clear
    echo -e "${C}"
    echo "   ___  _____    _(_)___  ___ "
    echo "  / _ \/  _/ |  / / / _ \/ _ \\"
    echo " / // // / | | / / / // /  __/"
    echo "/____/___/ |___/_/_//_/\___/ "
    echo -e "${N}"
    echo -e "${C}=== DIVINE TOOLS v7.5 ===${N}"
    echo ""
}

msg() { echo -e "${C}[*] ${W}$1${N}"; }
success() { echo -e "${G}[+] ${W}$1${N}"; }
error() { echo -e "${R}[!] ${W}$1${N}"; }

get_username() {
    local pkg=$1
    if command -v su >/dev/null; then
        # Attempt to read username from Roblox prefs
        local user=$(su -c "grep -o 'name=\"username\">[^<]*' /data/data/$pkg/shared_prefs/prefs.xml 2>/dev/null | cut -d'>' -f2")
        echo "$user"
    fi
}

# --- CONFIGURATION FUNCTIONS ---

configure_packages() {
    msg "Package Configuration"
    echo -e "${W}Current Packages:${N}"
    jq -r '.packages[]' "$CONFIG_FILE" | nl

    # 1. Package Detection
    echo -e "${W}Auto Detect [a] or Manual [m]?${N}"
    echo -ne "${Y}> ${N}" 
    read -r PKG_OPT < /dev/tty
    PKG_OPT=${PKG_OPT:-a}

    PACKAGES=()
    if [[ "$PKG_OPT" =~ ^[Mm]$ ]]; then
        echo -e "${W}Enter package names (space separated):${N}"
        echo -ne "${Y}> ${N}"
        read -r MANUAL_PKGS < /dev/tty
        IFS=' ' read -r -a PACKAGES <<< "$MANUAL_PKGS"
    else
        msg "Scanning..."
        # Fix: Use command substitution to avoid pipe subshell issues with read later
        # Use array assignment directly
        PACKAGES=($(pm list packages | grep roblox | cut -d: -f2))
        
        if [ ${#PACKAGES[@]} -eq 0 ]; then
            error "No packages found!"
            echo -e "${W}Enter manually:${N}"
            echo -ne "${Y}> ${N}"
            read -r MANUAL_PKGS < /dev/tty
            IFS=' ' read -r -a PACKAGES <<< "$MANUAL_PKGS"
        else
            success "Found ${#PACKAGES[@]} packages."
        fi
    fi

    # Save Packages immediately
    TMP=$(mktemp)
    jq --argjson pkgs "$(printf '%s\n' "${PACKAGES[@]}" | jq -R . | jq -s .)" '.packages = $pkgs' "$CONFIG_FILE" > "$TMP" && mv "$TMP" "$CONFIG_FILE"
    rm -f "$TMP"
}

configure_links() {
    # 2. Private Server Links
    msg "Private Servers"
    
    # Reload packages safely to ensure the array is populated
    if [ ${#PACKAGES[@]} -eq 0 ]; then
        PACKAGES=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && PACKAGES+=("$line")
        done < <(jq -r '.packages[] // empty' "$CONFIG_FILE")
    fi

    if [ ${#PACKAGES[@]} -eq 0 ]; then
        error "No packages found! Please configure packages first."
        return
    fi
    
    echo -e "${W}Use 1 Private Link for ALL accounts? [y/n]${N}"
    echo -ne "${Y}> ${N}" 
    read -r ONE_LINK < /dev/tty

    if [[ "$ONE_LINK" =~ ^[Yy]$ ]]; then
        echo -e "${W}Enter VIP Link:${N}"
        echo -ne "${Y}> ${N}" 
        read -r PS_URL < /dev/tty
        
        TMP=$(mktemp)
        jq --arg url "$PS_URL" '.private_servers.mode = "same" | .private_servers.url = $url' "$CONFIG_FILE" > "$TMP" && mv "$TMP" "$CONFIG_FILE"
        rm -f "$TMP"
    else
        # Set mode to per_package first
        TMP=$(mktemp)
        jq '.private_servers.mode = "per_package"' "$CONFIG_FILE" > "$TMP" && mv "$TMP" "$CONFIG_FILE"
        rm -f "$TMP"

        # Pre-fetch usernames to prevent su calls inside the input loop (Redfinger fix)
        msg "Loading account info..."
        declare -A USER_MAP
        for pkg in "${PACKAGES[@]}"; do
            USER_MAP["$pkg"]=$(get_username "$pkg")
        done

        while true; do
            header
            echo -e "${W}>>> PRIVATE SERVER LINKS${N}"
            echo -e "${C}------------------------------${N}"
            
            for ((i=0; i<${#PACKAGES[@]}; i++)); do
                local pkg="${PACKAGES[$i]}"
                local user="${USER_MAP[$pkg]}"
                local display="$pkg"
                [ -n "$user" ] && display="$pkg ($user)"
                
                local current_link=$(jq -r --arg pkg "$pkg" '.private_servers.urls[$pkg] // empty' "$CONFIG_FILE")
                local status="${R}[Empty]${N}"
                if [ -n "$current_link" ]; then status="${G}[Set]${N}"; fi
                
                echo -e " [${W}$((i+1))${N}] $display $status"
            done
            
            echo -e "${C}------------------------------${N}"
            echo -e "${W}Type number to edit, or 'd' when done.${N}"
            echo -ne "${Y}> ${N}" 
            read -r SEL < /dev/tty
            
            if [[ "$SEL" == "d" || "$SEL" == "D" ]]; then break; fi
            
            if [[ "$SEL" =~ ^[0-9]+$ ]] && [ "$SEL" -ge 1 ] && [ "$SEL" -le ${#PACKAGES[@]} ]; then
                local idx=$((SEL-1))
                local pkg="${PACKAGES[$idx]}"
                
                echo -e "${W}Enter URL for $pkg:${N}"
                echo -ne "${Y}> ${N}" 
                read -r LINK < /dev/tty
                
                if [ -n "$LINK" ]; then
                    TMP=$(mktemp)
                    jq --arg pkg "$pkg" --arg link "$LINK" '.private_servers.urls[$pkg] = $link' "$CONFIG_FILE" > "$TMP" && mv "$TMP" "$CONFIG_FILE"
                    rm -f "$TMP"
                fi
            fi
        done
    fi
}

configure_settings() {
    # 3. Username Masking
    msg "Dashboard Settings"
    echo -e "${W}Mask Usernames in Dashboard? (e.g. DIxxxNE) [y/n]${N}"
    echo -ne "${Y}> ${N}" 
    read -r MASK_OPT < /dev/tty
    MASKING=false
    [[ "$MASK_OPT" =~ ^[Yy]$ ]] && MASKING=true
    
    TMP=$(mktemp)
    jq --argjson mask $MASKING '.settings.masking = $mask' "$CONFIG_FILE" > "$TMP" && mv "$TMP" "$CONFIG_FILE"
    rm -f "$TMP"

    # 5. Timing Setup
    msg "Timing Settings"
    echo -e "${W}Launch Delay (seconds)? (Default 30)${N}"
    echo -ne "${Y}> ${N}" 
    read -r LAUNCH_DELAY < /dev/tty
    LAUNCH_DELAY=${LAUNCH_DELAY:-30}
    if [ "$LAUNCH_DELAY" -lt 30 ]; then LAUNCH_DELAY=30; fi

    echo -e "${W}Reset Interval (minutes)? (0=Off)${N}"
    echo -ne "${Y}> ${N}" 
    read -r RESET_INT < /dev/tty
    RESET_INT=${RESET_INT:-0}
    
    TMP=$(mktemp)
    jq --argjson ld $LAUNCH_DELAY --argjson ri $RESET_INT '.timing = {launch_delay: $ld, reset_interval: $ri}' "$CONFIG_FILE" > "$TMP" && mv "$TMP" "$CONFIG_FILE"
    rm -f "$TMP"
}

configure_webhook() {
    # 4. Webhook Setup
    msg "Webhook Settings"
    echo -e "${W}Enable Webhook? [y/n]${N}"
    echo -ne "${Y}> ${N}" 
    read -r WH_OPT < /dev/tty
    
    WH_ENABLED=false
    WH_URL=""
    WH_MODE="new"
    WH_INTERVAL=5

    if [[ "$WH_OPT" =~ ^[Yy]$ ]]; then
        WH_ENABLED=true
        echo -e "${W}Webhook URL:${N}"
        echo -ne "${Y}> ${N}" 
        read -r WH_URL < /dev/tty
        
        echo -e "${W}Mode (1. Send New, 2. Edit):${N}"
        echo -ne "${Y}> ${N}" 
        read -r WH_MODE_OPT < /dev/tty
        [[ "$WH_MODE_OPT" == "2" ]] && WH_MODE="edit"

        while true; do
            echo -e "${W}Interval (min 5 mins):${N}"
            echo -ne "${Y}> ${N}" 
            read -r WH_INTERVAL < /dev/tty
            if [[ "$WH_INTERVAL" =~ ^[0-9]+$ ]] && [ "$WH_INTERVAL" -ge 5 ]; then
                break
            else
                error "Minimum 5 minutes!"
            fi
        done
    fi
    
    TMP=$(mktemp)
    jq --argjson en $WH_ENABLED --arg url "$WH_URL" --arg mode "$WH_MODE" --argjson int "$WH_INTERVAL" \
       '.webhook = {enabled: $en, url: $url, mode: $mode, interval: $int}' "$CONFIG_FILE" > "$TMP" && mv "$TMP" "$CONFIG_FILE"
    rm -f "$TMP"
}

configure_autoexec() {
    # 6. Auto Execute Script
    msg "Auto-Execute Script"
    echo -e "${W}Configure Auto-Execute Script? [y/n]${N}"
    echo -ne "${Y}> ${N}" 
    read -r AUTO_EXEC_OPT < /dev/tty

    if [[ "$AUTO_EXEC_OPT" =~ ^[Yy]$ ]]; then
        echo -e "${W}Select Executor:${N}"
        echo -e "1. Delta"
        echo -e "2. Fluxus"
        echo -ne "${Y}> ${N}" 
        read -r EXEC_SEL < /dev/tty
        
        TARGET_DIR=""
        if [ "$EXEC_SEL" == "1" ]; then
            TARGET_DIR="/sdcard/Delta/Autoexecute"
        elif [ "$EXEC_SEL" == "2" ]; then
            TARGET_DIR="/sdcard/FluxusZ/autoexec"
        else
            error "Invalid selection, skipping auto-exec."
        fi

        if [ -n "$TARGET_DIR" ]; then
            msg "Creating directory: $TARGET_DIR"
            mkdir -p "$TARGET_DIR" 2>/dev/null || su -c "mkdir -p $TARGET_DIR"
            
            COUNT=1
            while true; do
                echo -e "${W}Paste content for script_${COUNT}.txt (Type 'END' on new line to finish):${N}"
                SCRIPT_CONTENT=""
                while IFS= read -r line < /dev/tty; do
                    [ "$line" == "END" ] && break
                    SCRIPT_CONTENT+="$line"$'\n'
                done

                FILE_PATH="$TARGET_DIR/script_${COUNT}.txt"
                TMP=$(mktemp)
                echo "$SCRIPT_CONTENT" > "$TMP"
                
                # Try writing directly, fallback to su
                if cp "$TMP" "$FILE_PATH" 2>/dev/null; then
                    success "Saved $FILE_PATH"
                else
                    cat "$TMP" | su -c "cat > $FILE_PATH" && success "Saved $FILE_PATH (Root)"
                fi
                rm "$TMP"

                echo -e "${W}Add another script? [y/n]${N}"
                echo -ne "${Y}> ${N}" 
                read -r AGAIN < /dev/tty
                if [[ "$AGAIN" != "y" ]]; then break; fi
                ((COUNT++))
            done
        fi
    fi
}

# Setup Wizard (Sequential)
setup_wizard() {
    header
    echo -e "${W}>>> CONFIGURATION WIZARD${N}"
    echo -e "${C}------------------------------${N}"
    
    configure_packages
    configure_links
    configure_webhook
    configure_settings
    configure_autoexec
    
    success "Configuration Saved!"
    echo -e "${W}Press Enter to return...${N}" 
    read -r dummy < /dev/tty
}

# Edit Configuration Sub-Menu
edit_config_menu() {
    while true; do
        header
        
        # Load current config for summary
        if [ -f "$CONFIG_FILE" ]; then
            PKG_COUNT=$(jq '.packages | length' "$CONFIG_FILE")
            PS_MODE=$(jq -r '.private_servers.mode' "$CONFIG_FILE")
            WH_ENABLED=$(jq -r '.webhook.enabled' "$CONFIG_FILE")
        else
            PKG_COUNT=0
            PS_MODE="N/A"
            WH_ENABLED="false"
        fi

        echo -e "${W}>>> EDIT CONFIGURATION (FD3 MODE)${N}"
        echo -e "${C}------------------------------${N}"
        echo -e "${W}Packages:       ${C}$PKG_COUNT configured${N}"
        echo -e "${W}Private Server: ${C}$PS_MODE${N}"
        echo -e "${W}Webhook:        ${C}$WH_ENABLED${N}"
        echo -e "${C}------------------------------${N}"
        
        echo -e "${C}1.${W} Package List"
        echo -e "${C}2.${W} Private Server URLs"
        echo -e "${C}3.${W} Webhook Settings"
        echo -e "${C}4.${W} Other Settings (Mask, Delay, etc.)"
        echo -e "${C}5.${W} Manage Auto-Execute Scripts"
        echo -e "${C}6.${W} View Full Configuration"
        echo -e "${C}7.${W} Back to Main Menu"
        echo -e "${C}------------------------------${N}"
        echo -ne "${Y}Select [1-7]: ${N}" 
        read -r SUB_OPT < /dev/tty

        case $SUB_OPT in
            1) # Edit Packages
                configure_packages
                ;;
            2) # Edit Private Servers
                configure_links
                ;;
            3) # Edit Webhook
                configure_webhook
                ;;
            4) # Other Settings
                configure_settings
                ;;
            5) # Manage Auto-Execute
                configure_autoexec
                ;;
            6) # View Full Config
                msg "Full Configuration"
                jq '.' "$CONFIG_FILE"
                read -r dummy < /dev/tty
                ;;
            7) return ;;
            *) error "Invalid Option" ;;
        esac
        echo -e "${W}Press Enter to continue...${N}" 
        read -r dummy < /dev/tty
    done
}

# Main Menu
while true; do
    header
    echo -e "${C}1.${W} Setup Configuration (First Run)"
    echo -e "${C}2.${W} Edit Configuration"
    echo -e "${C}3.${W} Run Script"
    echo -e "${C}4.${W} Clear All App Caches"
    echo -e "${C}5.${W} Exit"
    echo -e "${C}------------------------------${N}"
    echo -ne "${Y}Select [1-5]: ${N}" 
    read -r OPT < /dev/tty

    case $OPT in
        1) setup_wizard ;;
        2) 
            if [ -f "$CONFIG_FILE" ]; then
                edit_config_menu
            else
                error "Config not found! Run Setup first."
                echo -e "${W}Press Enter...${N}" 
                read -r dummy < /dev/tty
            fi
            ;;
        3) 
            if [ -f "run.sh" ]; then
                bash run.sh
            else
                error "run.sh not found!"
                echo -e "${W}Press Enter...${N}" 
                read -r dummy < /dev/tty
            fi
            ;;
        4)
            msg "Clearing caches..."
            if command -v su >/dev/null; then
                su -c "pm trim-caches 128G"
                success "Caches cleared (Root)"
            else
                error "Root required for global cache clear."
            fi
            sleep 2
            ;;
        5) exit 0 ;;
        *) print_error "Invalid Option"; sleep 1 ;;
    esac
done
