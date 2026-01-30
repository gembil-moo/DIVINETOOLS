#!/bin/bash
# DIVINE TOOLS - AUTOMATION
# Version 5.2

# Colors
C='\033[1;36m' # Cyan
G='\033[1;32m' # Green
R='\033[1;31m' # Red
W='\033[1;37m' # White
N='\033[0m'    # Reset

CONFIG_FILE="config/config.json"
mkdir -p config

# Header
header() {
    clear
    echo -e "${C}"
    echo "    ___  _____   _(_)___  ___ "
    echo "   / _ \/  _/ | / / / _ \/ _ \\"
    echo "  / // // / | |/ / / // /  __/"
    echo " /____/___/ |___/_/_//_/\___/ "
    echo -e "${N}"
    echo -e "${C}=== DIVINE TOOLS v5.2 ===${N}"
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

# Setup Wizard
setup_wizard() {
    header
    echo -e "${W}>>> CONFIGURATION WIZARD${N}"
    echo -e "${C}------------------------------${N}"

    # 1. Package Detection
    msg "Package Detection"
    echo -e "${W}Auto Detect [a] or Manual [m]?${N}"
    read -p "> " PKG_OPT
    PKG_OPT=${PKG_OPT:-a}

    PACKAGES=()
    if [[ "$PKG_OPT" =~ ^[Mm]$ ]]; then
        echo -e "${W}Enter package names (space separated):${N}"
        read -p "> " MANUAL_PKGS
        IFS=' ' read -r -a PACKAGES <<< "$MANUAL_PKGS"
    else
        msg "Scanning..."
        while IFS= read -r line; do
            [ -n "$line" ] && PACKAGES+=("$line")
        done < <(pm list packages | grep roblox | cut -d: -f2)
        
        if [ ${#PACKAGES[@]} -eq 0 ]; then
            error "No packages found!"
            echo -e "${W}Enter manually:${N}"
            read -p "> " MANUAL_PKGS
            IFS=' ' read -r -a PACKAGES <<< "$MANUAL_PKGS"
        else
            success "Found ${#PACKAGES[@]} packages."
        fi
    fi

    # 2. Private Server Links
    echo ""
    msg "Private Servers"
    echo -e "${W}Use 1 Private Link for ALL accounts? [y/n]${N}"
    read -p "> " ONE_LINK

    PS_MODE="per_package"
    PS_URL=""
    declare -A PS_URLS

    if [[ "$ONE_LINK" =~ ^[Yy]$ ]]; then
        PS_MODE="same"
        echo -e "${W}Enter VIP Link:${N}"
        read -p "> " PS_URL
    else
        for pkg in "${PACKAGES[@]}"; do
            local user=$(get_username "$pkg")
            local display="$pkg"
            [ -n "$user" ] && display="$pkg ($user)"
            echo -e "${W}Link for $display:${N}"
            read -p "> " LINK
            PS_URLS["$pkg"]="$LINK"
        done
    fi

    # 3. Username Masking
    echo ""
    msg "Dashboard Settings"
    echo -e "${W}Mask Usernames in Dashboard? (e.g. DIxxxNE) [y/n]${N}"
    read -p "> " MASK_OPT
    MASKING=false
    [[ "$MASK_OPT" =~ ^[Yy]$ ]] && MASKING=true

    # 4. Webhook Setup
    echo ""
    msg "Webhook Settings"
    echo -e "${W}Enable Webhook? [y/n]${N}"
    read -p "> " WH_OPT
    
    WH_ENABLED=false
    WH_URL=""
    WH_MODE="new"
    WH_INTERVAL=5

    if [[ "$WH_OPT" =~ ^[Yy]$ ]]; then
        WH_ENABLED=true
        echo -e "${W}Webhook URL:${N}"
        read -p "> " WH_URL
        
        echo -e "${W}Mode (1. Send New, 2. Edit):${N}"
        read -p "> " WH_MODE_OPT
        [[ "$WH_MODE_OPT" == "2" ]] && WH_MODE="edit"

        while true; do
            echo -e "${W}Interval (min 5 mins):${N}"
            read -p "> " WH_INTERVAL
            if [[ "$WH_INTERVAL" =~ ^[0-9]+$ ]] && [ "$WH_INTERVAL" -ge 5 ]; then
                break
            else
                error "Minimum 5 minutes!"
            fi
        done
    fi

    # 5. Timing Setup
    echo ""
    msg "Timing Settings"
    echo -e "${W}Launch Delay (seconds)? (Default 30)${N}"
    read -p "> " LAUNCH_DELAY
    LAUNCH_DELAY=${LAUNCH_DELAY:-30}
    if [ "$LAUNCH_DELAY" -lt 30 ]; then LAUNCH_DELAY=30; fi

    echo -e "${W}Reset Interval (minutes)? (0=Off)${N}"
    read -p "> " RESET_INT
    RESET_INT=${RESET_INT:-0}

    # 6. Auto Execute Script
    echo ""
    msg "Auto-Execute Script"
    echo -e "${W}Configure Auto-Execute Script? [y/n]${N}"
    read -p "> " AUTO_EXEC_OPT

    if [[ "$AUTO_EXEC_OPT" =~ ^[Yy]$ ]]; then
        echo -e "${W}Select Executor:${N}"
        echo -e "1. Delta"
        echo -e "2. Fluxus"
        read -p "> " EXEC_SEL
        
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
            
            SCRIPT_IDX=1
            while true; do
                echo -e "${W}Create script_${SCRIPT_IDX}.txt? [y/n]${N}"
                read -p "> " CREATE_SCRIPT
                if [[ ! "$CREATE_SCRIPT" =~ ^[Yy]$ ]]; then break; fi

                echo -e "${W}Paste script content (Type 'END' on new line to finish):${N}"
                SCRIPT_CONTENT=""
                while IFS= read -r line; do
                    [ "$line" == "END" ] && break
                    SCRIPT_CONTENT+="$line"$'\n'
                done

                FILE_PATH="$TARGET_DIR/script_${SCRIPT_IDX}.txt"
                TMP=$(mktemp)
                echo "$SCRIPT_CONTENT" > "$TMP"
                
                # Try writing directly, fallback to su
                if cp "$TMP" "$FILE_PATH" 2>/dev/null; then
                    success "Saved $FILE_PATH"
                else
                    cat "$TMP" | su -c "cat > $FILE_PATH" && success "Saved $FILE_PATH (Root)"
                fi
                rm "$TMP"
                ((SCRIPT_IDX++))
            done
        fi
    fi

    # Save Config
    msg "Saving Configuration..."
    
    # Construct JSON
    JSON_PKGS=$(printf '%s\n' "${PACKAGES[@]}" | jq -R . | jq -s .)
    
    if [ "$PS_MODE" == "same" ]; then
        JSON_PS=$(jq -n --arg m "$PS_MODE" --arg u "$PS_URL" '{mode: $m, url: $u, urls: {}}')
    else
        JSON_URLS="{}"
        for pkg in "${!PS_URLS[@]}"; do
            JSON_URLS=$(echo "$JSON_URLS" | jq --arg k "$pkg" --arg v "${PS_URLS[$pkg]}" '.[$k] = $v')
        done
        JSON_PS=$(jq -n --arg m "$PS_MODE" --argjson u "$JSON_URLS" '{mode: $m, url: "", urls: $u}')
    fi

    JSON_WEBHOOK=$(jq -n --argjson en $WH_ENABLED --arg u "$WH_URL" --arg m "$WH_MODE" --argjson i $WH_INTERVAL '{enabled: $en, url: $u, mode: $m, interval: $i}')
    JSON_TIMING=$(jq -n --argjson ld $LAUNCH_DELAY --argjson ri $RESET_INT '{launch_delay: $ld, reset_interval: $ri}')
    JSON_SETTINGS=$(jq -n --argjson mu $MASKING '{masking: $mu, enable_swap: true, swap_size_mb: 2048, enable_cpu_boost: true}')

    jq -n \
        --argjson pkgs "$JSON_PKGS" \
        --argjson ps "$JSON_PS" \
        --argjson wh "$JSON_WEBHOOK" \
        --argjson tm "$JSON_TIMING" \
        --argjson set "$JSON_SETTINGS" \
        '{packages: $pkgs, private_servers: $ps, webhook: $wh, timing: $tm, settings: $st}' \
        > "$CONFIG_FILE"

    success "Configuration Saved!"
    read -p "Press Enter to return..."
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
    read -p "Select [1-5]: " OPT

    case $OPT in
        1|2) setup_wizard ;;
        3) 
            if [ -f "run.sh" ]; then
                bash run.sh
            else
                error "run.sh not found!"
                read -p "Press Enter..."
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
