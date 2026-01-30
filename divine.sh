#!/bin/bash
# DIVINE TOOLS - PREMIUM UI
# Version 3.1 (Kaeru Style)

# --- WARNA (CYAN THEME) ---
C='\033[1;36m' # Cyan (Mirip Kaeru)
G='\033[1;32m' # Green
R='\033[1;31m' # Red
W='\033[1;37m' # White
N='\033[0m'    # Reset

CONF_FILE="config/config.json"

# --- LOGO ASCII ---
show_logo() {
    clear
    echo -e "${C}"
    echo "  ██████╗ ██╗██╗   ██╗██╗███╗   ██╗███████╗"
    echo "  ██╔══██╗██║██║   ██║██║████╗  ██║██╔════╝"
    echo "  ██║  ██║██║██║   ██║██║██╔██╗ ██║█████╗  "
    echo "  ██║  ██║██║╚██╗ ██╔╝██║██║╚██╗██║██╔══╝  "
    echo "  ██████╔╝██║ ╚████╔╝ ██║██║ ╚████║███████╗"
    echo "  ╚═════╝ ╚═╝  ╚═══╝  ╚═╝╚═╝  ╚═══╝╚══════╝"
    echo -e "         Version 3.1 (Premium Edition)${N}"
    echo -e "${W}--------------------------------------------------${N}"
}

# --- FUNGSI ---
setup_config() {
    # Logic First Config (Singkat aja, detailnya sdh ada di code sblmnya)
    echo -e "\n${G}[*] Starting Configuration Wizard...${N}"
    # ... (Logic config sama seperti sebelumnya, cuma panggil bash baru biar rapi)
    bash .setup_wizard.sh # Nanti kita pisah logic setupnya biar menu bersih
    read -p "Press Enter to return..."
}

# --- MENU UTAMA ---
while true; do
    show_logo
    echo -e "${C}What would you like to do?${N}"
    echo -e "  ${G}1)${N} Setup Configuration (First Run)"
    echo -e "  ${G}2)${N} Edit Configuration"
    echo -e "  ${G}3)${N} Run DIVINE (Launch & Dashboard)"
    echo -e "  ${G}4)${N} Clear Cache & Logs"
    echo -e "  ${G}5)${N} Uninstall DIVINE"
    echo -e "  ${G}6)${N} Exit"
    echo ""
    read -p "$(echo -e "[?] Enter your choice [1-6]: ")" CHOICE

    case $CHOICE in
        1) 
            # Logic Setup (Simpelnya kita panggil setup script/function)
            echo "Jalankan setup wizard..." ;; 
            # Nanti copas logic setup yg panjang tadi ke sini/file terpisah
        2) nano $CONF_FILE ;;
        3) bash run.sh ;;
        4) rm -rf logs/*; echo "Cache cleared!"; sleep 1 ;;
        5) rm -rf *; echo "Uninstalled."; exit ;;
        6) echo "Bye!"; exit ;;
        *) echo "Invalid option!"; sleep 1 ;;
    esac
done
