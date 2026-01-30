#!/bin/bash
# DIVINE TOOLS - PREMIUM UI
# Version 4.0 (Expert Edition)

# --- COLORS ---
C='\033[1;36m' # Cyan
G='\033[1;32m' # Green
R='\033[1;31m' # Red
Y='\033[1;33m' # Yellow
W='\033[1;37m' # White
N='\033[0m'    # Reset

CONFIG_FILE="config/config.json"
mkdir -p config

# --- UTILS ---
show_header() {
    clear
    echo -e "${C}"
    echo "  ██████╗ ██╗██╗   ██╗██╗███╗   ██╗███████╗"
    echo "  ██╔══██╗██║██║   ██║██║████╗  ██║██╔════╝"
    echo "  ██║  ██║██║██║   ██║██║██╔██╗ ██║█████╗  "
    echo "  ██║  ██║██║╚██╗ ██╔╝██║██║╚██╗██║██╔══╝  "
    echo "  ██████╔╝██║ ╚████╔╝ ██║██║ ╚████║███████╗"
    echo "  ╚═════╝ ╚═╝  ╚═══╝  ╚═╝╚═╝  ╚═══╝╚══════╝"
    echo -e "         ${W}PREMIUM AUTOMATION TOOL${C}"
    echo -e "${C}==================================================${N}"
}

print_status() { echo -e "${C}[*] $1${N}"; }
print_success() { echo -e "${G}[+] $1${N}"; }
print_error() { echo -e "${R}[!] $1${N}"; }

# --- SETUP WIZARD ---
setup_wizard() {
    show_header
    echo -e "${Y}>>> CONFIGURATION WIZARD${N}"
    echo ""

    # 1. Initialize
    echo "{}" > "$CONFIG_FILE"
    
    # 2. Package Detection
    PACKAGES=()
    echo -e "${C}[?] Auto Detect Packages? [y/n]${N}"
    read -p "> " AUTO_DETECT
    
    if [[ "$AUTO_DETECT" =~ ^[Yy]$ ]]; then
        print_status "Scanning for Roblox packages..."
        # Get list, remove 'package:', filter empty
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                PACKAGES+=("$line")
            fi
        done < <(pm list packages | grep roblox | cut -d: -f2)
        
        if [ ${#PACKAGES[@]} -eq 0 ]; then
            print_error "No packages found! Switching to manual mode."
            AUTO_DETECT="n"
        else
            print_success "Found ${#PACKAGES[@]} packages."
        fi
    fi
    
    if [[ ! "$AUTO_DETECT" =~ ^[Yy]$ ]]; then
        echo -e "${C}[?] Enter package names separated by space:${N}"
        read -p "> " MANUAL_PKGS
        IFS=' ' read -r -a PACKAGES <<< "$MANUAL_PKGS"
    fi

    # Save Packages to JSON
    jq -n --argjson pkgs "$(printf '%s\n' "${PACKAGES[@]}" | jq -R . | jq -s .)" \
          '{packages: $pkgs}' > "$CONFIG_FILE"

    # 3. Link Setup
    echo ""
    echo -e "${C}[?] Use 1 Private Server Link for ALL accounts? [y/n]${N}"
    read -p "> " ONE_LINK
    
    PS_MODE="per_package"
    PS_URL=""
    declare -A PS_URLS
    
    if [[ "$ONE_LINK" =~ ^[Yy]$ ]]; then
        PS_MODE="same"
        echo -e "${C}[?] Enter Private Server Link:${N}"
        read -p "> " PS_URL
    else
        for pkg in "${PACKAGES[@]}"; do
            echo -e "${C}[?] Enter Link for $pkg:${N}"
            read -p "> " LINK
            PS_URLS["$pkg"]="$LINK"
        done
    fi
    
    # Update JSON with Links
    TMP_JSON=$(mktemp)
    if [ "$PS_MODE" == "same" ]; then
        jq --arg mode "$PS_MODE" --arg url "$PS_URL" \
           '.private_servers = {mode: $mode, url: $url}' "$CONFIG_FILE" > "$TMP_JSON"
    else
        # Construct JSON object for urls
        URLS_JSON="{}"
        for pkg in "${!PS_URLS[@]}"; do
            URLS_JSON=$(echo "$URLS_JSON" | jq --arg k "$pkg" --arg v "${PS_URLS[$pkg]}" '.[$k] = $v')
        done
        jq --arg mode "$PS_MODE" --argjson urls "$URLS_JSON" \
           '.private_servers = {mode: $mode, urls: $urls}' "$CONFIG_FILE" > "$TMP_JSON"
    fi
    mv "$TMP_JSON" "$CONFIG_FILE"

    # 4. Webhook Setup
    echo ""
    echo -e "${C}[?] Enable Webhook? [y/n]${N}"
    read -p "> " ENABLE_WH
    
    WH_ENABLED=false
    WH_URL=""
    WH_MODE=1
    WH_INTERVAL=5
    
    if [[ "$ENABLE_WH" =~ ^[Yy]$ ]]; then
        WH_ENABLED=true
        echo -e "${C}[?] Webhook URL:${N}"
        read -p "> " WH_URL
        echo -e "${C}[?] Mode (1=Send New, 2=Edit):${N}"
        read -p "> " WH_MODE
        echo -e "${C}[?] Interval (min 5 mins):${N}"
        read -p "> " WH_INTERVAL
        if [ "$WH_INTERVAL" -lt 5 ]; then WH_INTERVAL=5; fi
    fi
    
    # Update JSON Webhook
    TMP_JSON=$(mktemp)
    jq --argjson en $WH_ENABLED --arg url "$WH_URL" --argjson mode $WH_MODE --argjson int $WH_INTERVAL \
       '.webhook = {enabled: $en, url: $url, mode: $mode, interval: $int}' "$CONFIG_FILE" > "$TMP_JSON"
    mv "$TMP_JSON" "$CONFIG_FILE"

    # 5. Timing Setup
    echo ""
    echo -e "${C}[?] Launch Delay (seconds) [Default: 5]:${N}"
    read -p "> " LAUNCH_DELAY
    LAUNCH_DELAY=${LAUNCH_DELAY:-5}
    
    echo -e "${C}[?] Reset/Rejoin Interval (minutes) [0=Off]:${N}"
    read -p "> " RESET_INT
    RESET_INT=${RESET_INT:-0}
    
    # Update JSON Timing
    TMP_JSON=$(mktemp)
    jq --argjson ld $LAUNCH_DELAY --argjson ri $RESET_INT \
       '.timing = {launch_delay: $ld, reset_interval: $ri}' "$CONFIG_FILE" > "$TMP_JSON"
    mv "$TMP_JSON" "$CONFIG_FILE"

    # 6. Auto Execute
    echo ""
    echo -e "${C}[?] Inject Auto-Execute Script? [y/n]${N}"
    read -p "> " INJECT_SCRIPT
    
    if [[ "$INJECT_SCRIPT" =~ ^[Yy]$ ]]; then
        echo -e "${C}Select Executor Folder:${N}"
        echo "1. Delta (autoexec)"
        echo "2. Fluxus (autoexec)"
        echo "3. Manual Input"
        read -p "> " EXEC_OPT
        
        EXEC_FOLDER="autoexec"
        case $EXEC_OPT in
            1) EXEC_FOLDER="autoexec" ;;
            2) EXEC_FOLDER="autoexec" ;;
            3) read -p "Enter folder name: " EXEC_FOLDER ;;
            *) EXEC_FOLDER="autoexec" ;;
        esac
        
        SCRIPT_COUNT=1
        while true; do
            echo ""
            echo -e "${C}[?] Configure script_${SCRIPT_COUNT}.txt? [y/n]${N}"
            read -p "> " CONF_SCRIPT
            if [[ ! "$CONF_SCRIPT" =~ ^[Yy]$ ]]; then break; fi
            
            echo -e "${Y}Paste script content below. Type 'END' on a new line to finish:${N}"
            SCRIPT_CONTENT=""
            while IFS= read -r line; do
                if [ "$line" == "END" ]; then break; fi
                SCRIPT_CONTENT+="$line"$'\n'
            done
            
            print_status "Writing script to packages..."
            for pkg in "${PACKAGES[@]}"; do
                # Path: /sdcard/Android/data/[PKG]/files/[FOLDER]/script_X.txt
                TARGET_DIR="/sdcard/Android/data/$pkg/files/$EXEC_FOLDER"
                TARGET_FILE="$TARGET_DIR/script_${SCRIPT_COUNT}.txt"
                
                # Create Dir
                su -c "mkdir -p $TARGET_DIR"
                
                # Write File (Using pipe to su to avoid permission issues)
                TMP_SCRIPT=$(mktemp)
                echo "$SCRIPT_CONTENT" > "$TMP_SCRIPT"
                cat "$TMP_SCRIPT" | su -c "cat > $TARGET_FILE"
                rm "$TMP_SCRIPT"
                
                print_success "Wrote to $pkg"
            done
            ((SCRIPT_COUNT++))
        done
    fi
    
    print_success "Configuration Complete!"
    read -p "Press Enter to return..."
}

# --- MAIN LOOP ---
while true; do
    show_header
    echo -e "${C}  [1] First Configuration (Setup Wizard)${N}"
    echo -e "${C}  [2] Run DIVINE (Launch Dashboard)${N}"
    echo -e "${C}  [3] Edit Configuration (Nano)${N}"
    echo -e "${C}  [4] Clear Cache${N}"
    echo -e "${C}  [5] Uninstall${N}"
    echo -e "${C}  [6] Exit${N}"
    echo ""
    echo -e "${C}==================================================${N}"
    read -p "  Select Option [1-6]: " OPTION
    
    case $OPTION in
        1) setup_wizard ;;
        2) 
            if [ -f "run.sh" ]; then bash run.sh; else print_error "run.sh not found!"; sleep 2; fi 
            ;;
        3) nano "$CONFIG_FILE" ;;
        4) 
            rm -rf logs/* 2>/dev/null
            print_success "Cache cleared."
            sleep 1
            ;;
        5)
            echo -e "${R}Are you sure you want to uninstall? [y/n]${N}"
            read -p "> " CONFIRM
            if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                rm -rf config logs src *.sh *.json
                echo "Uninstalled."
                exit 0
            fi
            ;;
        6) exit 0 ;;
        *) print_error "Invalid Option"; sleep 1 ;;
    esac
done
