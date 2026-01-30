#!/bin/bash
# DIVINE TOOLS - COMPACT MENU
# Version 4.2

# --- COLORS ---
C='\033[1;36m' # Cyan
W='\033[1;37m' # White
G='\033[1;32m' # Green
R='\033[1;31m' # Red
N='\033[0m'    # Reset

CONFIG_FILE="config/config.json"
mkdir -p config

# --- UTILS ---
header() {
    clear
    echo -e "${C}"
    echo "  ██████╗ ██╗██╗   ██╗██╗███╗   ██╗███████╗"
    echo "  ██╔══██╗██║██║   ██║██║████╗  ██║██╔════╝"
    echo "  ██║  ██║██║██║   ██║██║██╔██╗ ██║█████╗  "
    echo "  ██║  ██║██║╚██╗ ██╔╝██║██║╚██╗██║██╔══╝  "
    echo "  ██████╔╝██║ ╚████╔╝ ██║██║ ╚████║███████╗"
    echo "  ╚═════╝ ╚═╝  ╚═══╝  ╚═╝╚═╝  ╚═══╝╚══════╝"
    echo -e "           ${C}DIVINE TOOLS v4.2${N}"
    echo -e "${C}=============================================${N}"
}

msg() { echo -e "${C}[*] ${W}$1${N}"; }
success() { echo -e "${G}[+] ${W}$1${N}"; }
error() { echo -e "${R}[!] ${W}$1${N}"; }

# --- SETUP WIZARD ---
setup() {
    header
    echo -e "${W}>>> SETUP WIZARD${N}"
    echo -e "${C}---------------------------------------------${N}"

    # 1. Auto-Detect
    msg "Scanning packages..."
    PACKAGES=()
    while IFS= read -r line; do
        [ -n "$line" ] && PACKAGES+=("$line")
    done < <(pm list packages | grep roblox | cut -d: -f2)

    if [ ${#PACKAGES[@]} -eq 0 ]; then
        error "No Roblox packages found!"
        echo -e "${W}Enter manually (space sep):${N}"
        read -p "> " MANUAL
        IFS=' ' read -r -a PACKAGES <<< "$MANUAL"
    else
        success "Found ${#PACKAGES[@]} packages."
    fi

    # 2. Link Setup
    echo ""
    msg "Private Server Setup"
    echo -e "${W}Use 1 VIP Link for ALL accounts? [y/n]${N}"
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
            echo -e "${W}Link for $pkg:${N}"
            read -p "> " LINK
            PS_URLS["$pkg"]="$LINK"
        done
    fi

    # 3. Window Mode
    echo ""
    msg "Window Settings"
    echo -e "${W}Enable Freeform/Small Window? [y/n]${N}"
    read -p "> " WIN_MODE
    ENABLE_WINDOW=false
    [[ "$WIN_MODE" =~ ^[Yy]$ ]] && ENABLE_WINDOW=true

    # 4. Auto-Execute
    echo ""
    msg "Auto-Execute Setup"
    echo -e "${W}Inject Auto-Execute Script? [y/n]${N}"
    read -p "> " INJECT

    if [[ "$INJECT" =~ ^[Yy]$ ]]; then
        echo -e "${W}Select Executor:${N}"
        echo -e "  1. Delta (/sdcard/Delta/Autoexecute)"
        echo -e "  2. Fluxus (/sdcard/FluxusZ/autoexec)"
        echo -e "  3. Custom Path"
        read -p "> " EXEC_OPT

        TARGET_DIR=""
        case $EXEC_OPT in
            1) TARGET_DIR="/sdcard/Delta/Autoexecute" ;;
            2) TARGET_DIR="/sdcard/FluxusZ/autoexec" ;;
            3) read -p "Enter full path: " TARGET_DIR ;;
            *) error "Invalid option."; TARGET_DIR="" ;;
        esac

        if [ -n "$TARGET_DIR" ]; then
            echo -e "${W}Paste script (Type END on new line):${N}"
            SCRIPT=""
            while IFS= read -r line; do
                [ "$line" == "END" ] && break
                SCRIPT+="$line"$'\n'
            done

            msg "Saving script..."
            su -c "mkdir -p $TARGET_DIR"
            TMP=$(mktemp)
            echo "$SCRIPT" > "$TMP"
            cat "$TMP" | su -c "cat > $TARGET_DIR/divine_script.txt"
            rm "$TMP"
            success "Saved to $TARGET_DIR/divine_script.txt"
        fi
    fi

    # 5. Save Config
    msg "Saving configuration..."
    
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

    JSON_SETTINGS=$(jq -n --argjson wm $ENABLE_WINDOW '{enable_window: $wm, enable_swap: true, swap_size_mb: 2048, enable_cpu_boost: true}')

    jq -n \
        --argjson pkgs "$JSON_PKGS" \
        --argjson ps "$JSON_PS" \
        --argjson set "$JSON_SETTINGS" \
        '{packages: $pkgs, private_servers: $ps, settings: $set, webhook: {enabled: false}, timing: {launch_delay: 5}}' \
        > "$CONFIG_FILE"

    success "Config Saved!"
    read -p "Press Enter..."
}

# --- MAIN MENU ---
while true; do
    header
    echo -e "${C}1.${W} Setup Wizard"
    echo -e "${C}2.${W} Start Farming"
    echo -e "${C}3.${W} Edit Config"
    echo -e "${C}4.${W} Clear Cache"
    echo -e "${C}5.${W} Exit"
    echo -e "${C}---------------------------------------------${N}"
    read -p "Select [1-5]: " OPT

    case $OPT in
        1) setup ;;
        2) [ -f run.sh ] && bash run.sh || error "run.sh missing" ;;
        3) nano "$CONFIG_FILE" ;;
        4) rm -rf logs/* 2>/dev/null; success "Cache Cleared"; sleep 1 ;;
        5) exit 0 ;;
        *) print_error "Invalid Option"; sleep 1 ;;
    esac
done
