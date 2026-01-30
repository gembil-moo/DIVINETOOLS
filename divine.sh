#!/bin/bash
# DIVINE TOOLS - AUTOMATION
# Version 5.6 (Redfinger Bypass)

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
    echo "   ___  _____    _(_)___  ___"
    echo "  / _ \/  _/ |  / / / _ \/ _ \\"
    echo " / // // / | | / / / // /  __/"
    echo "/____/___/ |___/_/_/_//_/\\___/"
    echo -e "${N}"
    echo -e "${C}=== DIVINE TOOLS v5.6 ===${N}"
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
    echo -ne "> "
    read PKG_OPT
    PKG_OPT=${PKG_OPT:-a}

    PACKAGES=()
    if [[ "$PKG_OPT" =~ ^[Mm]$ ]]; then
        echo -e "${W}Enter package names (space separated):${N}"
        echo -ne "> "
        read MANUAL_PKGS
        IFS=' ' read -r -a PACKAGES <<< "$MANUAL_PKGS"
    else
        msg "Scanning..."
        # Fix: Use command substitution to avoid pipe subshell issues with read later
        DETECTED_PKGS=$(pm list packages | grep roblox | cut -d: -f2)
        # Convert newline separated string to array
        mapfile -t PACKAGES <<< "$DETECTED_PKGS"
        
        if [ ${#PACKAGES[@]} -eq 0 ]; then
            error "No packages found!"
            echo -e "${W}Enter manually:${N}"
            echo -ne "> "
            read MANUAL_PKGS
            IFS=' ' read -r -a PACKAGES <<< "$MANUAL_PKGS"
        else
            success "Found ${#PACKAGES[@]} packages."
        fi
    fi

    # 2. Private Server Links
    echo ""
    msg "Private Servers"
    echo -e "${W}Use 1 Private Link for ALL accounts? [y/n]${N}"
    echo -ne "> "
    read ONE_LINK

    PS_MODE="per_package"
    PS_URL=""
    declare -A PS_URLS

    if [[ "$ONE_LINK" =~ ^[Yy]$ ]]; then
        PS_MODE="same"
        echo -e "${W}Enter VIP Link:${N}"
        echo -ne "> "
        read PS_URL
    else
        # REDFINGER BYPASS: DO NOT LOOP INPUT
        echo -e "${R}!! Skipping manual input to prevent Redfinger Freeze !!${N}"
        echo -e "${W}[*] All links set to placeholder. Please edit config.json manually later.${N}"
        
        for pkg in "${PACKAGES[@]}"; do
            if [ -n "$pkg" ]; then
                PS_URLS["$pkg"]="https://EDIT_ME_LATER"
            fi
        done
    fi

    # 3. Username Masking
    echo ""
    msg "Dashboard Settings"
    echo -e "${W}Mask Usernames in Dashboard? (e.g. DIxxxNE) [y/n]${N}"
    echo -ne "> "
    read MASK_OPT
    MASKING=false
    [[ "$MASK_OPT" =~ ^[Yy]$ ]] && MASKING=true

    # 4. Webhook Setup
    echo ""
    msg "Webhook Settings"
    echo -e "${W}Enable Webhook? [y/n]${N}"
    echo -ne "> "
    read WH_OPT
    
    WH_ENABLED=false
    WH_URL=""
    WH_MODE="new"
    WH_INTERVAL=5

    if [[ "$WH_OPT" =~ ^[Yy]$ ]]; then
        WH_ENABLED=true
        echo -e "${W}Webhook URL:${N}"
        echo -ne "> "
        read WH_URL
        
        echo -e "${W}Mode (1. Send New, 2. Edit):${N}"
        echo -ne "> "
        read WH_MODE_OPT
        [[ "$WH_MODE_OPT" == "2" ]] && WH_MODE="edit"

        while true; do
            echo -e "${W}Interval (min 5 mins):${N}"
            echo -ne "> "
            read WH_INTERVAL
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
    echo -ne "> "
    read LAUNCH_DELAY
    LAUNCH_DELAY=${LAUNCH_DELAY:-30}
    if [ "$LAUNCH_DELAY" -lt 30 ]; then LAUNCH_DELAY=30; fi

    echo -e "${W}Reset Interval (minutes)? (0=Off)${N}"
    echo -ne "> "
    read RESET_INT
    RESET_INT=${RESET_INT:-0}

    # 6. Auto Execute Script
    echo ""
    msg "Auto-Execute Script"
    echo -e "${W}Configure Auto-Execute Script? [y/n]${N}"
    echo -ne "> "
    read AUTO_EXEC_OPT

    if [[ "$AUTO_EXEC_OPT" =~ ^[Yy]$ ]]; then
        echo -e "${W}Select Executor:${N}"
        echo -e "1. Delta"
        echo -e "2. Fluxus"
        echo -ne "> "
        read EXEC_SEL
        
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
            
            echo -e "${W}Create one script for all? [y/n]${N}"
            echo -ne "> "
            read CREATE_SCRIPT
            
            if [[ "$CREATE_SCRIPT" =~ ^[Yy]$ ]]; then
                echo -e "${W}Paste script content (Type 'END' on new line to finish):${N}"
                SCRIPT_CONTENT=""
                while IFS= read -r line; do
                    [ "$line" == "END" ] && break
                    SCRIPT_CONTENT+="$line"$'\n'
                done

                FILE_PATH="$TARGET_DIR/divine_script.lua"
                TMP=$(mktemp)
                echo "$SCRIPT_CONTENT" > "$TMP"
                
                # Try writing directly, fallback to su
                if cp "$TMP" "$FILE_PATH" 2>/dev/null; then
                    success "Saved $FILE_PATH"
                else
                    cat "$TMP" | su -c "cat > $FILE_PATH" && success "Saved $FILE_PATH (Root)"
                fi
                rm "$TMP"
            fi
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
    echo -ne "Press Enter to return..."
    read
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

        echo -e "${W}>>> EDIT CONFIGURATION (SAFE MODE)${N}"
        echo -e "${C}------------------------------${N}"
        echo -e "${W}Packages:       ${C}$PKG_COUNT configured${N}"
        echo -e "${W}Private Server: ${C}$PS_MODE${N}"
        echo -e "${W}Webhook:        ${C}$WH_ENABLED${N}"
        echo -e "${C}------------------------------${N}"
        
        echo -e "${C}1.${W} View Package List"
        echo -e "${C}2.${W} Edit Config File (Nano)"
        echo -e "${C}3.${W} Manage Auto-Execute"
        echo -e "${C}4.${W} Back to Main Menu"
        echo -e "${C}------------------------------${N}"
        echo -ne "Select [1-4]: "
        read SUB_OPT

        case $SUB_OPT in
            1) # View Packages
                msg "Package List"
                if [ -f "$CONFIG_FILE" ]; then
                    jq -r '.packages[]' "$CONFIG_FILE" | nl
                else
                    error "No config found."
                fi
                ;;
            2) # Edit Config File
                msg "Opening Nano..."
                if command -v nano >/dev/null; then
                    nano "$CONFIG_FILE"
                else
                    error "Nano not installed. Please install nano."
                fi
                ;;
            3) # Manage Auto-Execute
                msg "Manage Auto-Execute"
                echo -e "${W}Select Executor:${N}"
                echo -e "1. Delta"
                echo -e "2. Fluxus"
                echo -ne "> "
                read EXEC_SEL
                
                TARGET_DIR=""
                if [ "$EXEC_SEL" == "1" ]; then
                    TARGET_DIR="/sdcard/Delta/Autoexecute"
                elif [ "$EXEC_SEL" == "2" ]; then
                    TARGET_DIR="/sdcard/FluxusZ/autoexec"
                else
                    error "Invalid selection"
                    continue
                fi
                
                if [ -n "$TARGET_DIR" ]; then
                    msg "Target: $TARGET_DIR"
                    mkdir -p "$TARGET_DIR" 2>/dev/null || su -c "mkdir -p $TARGET_DIR"
                    
                    echo -e "${W}[1] Create New Script${N}"
                    echo -e "${W}[2] Delete All Scripts in Folder${N}"
                    echo -ne "> "
                    read ACTION
                    
                    if [ "$ACTION" == "1" ]; then
                        echo -e "${W}Filename (e.g. script.txt):${N}"
                        echo -ne "> "
                        read FNAME
                        echo -e "${W}Paste content (END to finish):${N}"
                        CONTENT=""
                        while IFS= read -r line; do
                            [ "$line" == "END" ] && break
                            CONTENT+="$line"$'\n'
                        done
                        
                        FILE_PATH="$TARGET_DIR/$FNAME"
                        TMP=$(mktemp)
                        echo "$CONTENT" > "$TMP"
                        if cp "$TMP" "$FILE_PATH" 2>/dev/null; then
                            success "Saved $FILE_PATH"
                        else
                            cat "$TMP" | su -c "cat > $FILE_PATH" && success "Saved $FILE_PATH (Root)"
                        fi
                        rm "$TMP"
                    elif [ "$ACTION" == "2" ]; then
                        rm "$TARGET_DIR"/*.txt 2>/dev/null || su -c "rm $TARGET_DIR/*.txt"
                        success "Cleared scripts in $TARGET_DIR"
                    fi
                fi
                ;;
            4) return ;;
            *) error "Invalid Option" ;;
        esac
        echo -ne "Press Enter to continue..."
        read
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
    echo -ne "Select [1-5]: "
    read OPT

    case $OPT in
        1) setup_wizard ;;
        2) 
            if [ -f "$CONFIG_FILE" ]; then
                edit_config_menu
            else
                error "Config not found! Run Setup first."
                echo -ne "Press Enter..."
                read
            fi
            ;;
        3) 
            if [ -f "run.sh" ]; then
                bash run.sh
            else
                error "run.sh not found!"
                echo -ne "Press Enter..."
                read
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
