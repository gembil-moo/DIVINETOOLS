#!/bin/bash
# DIVINE DASHBOARD - TABLE VIEW

# --- WARNA ---
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; N='\033[0m'
CONF="config/config.json"

if [ ! -f "$CONF" ]; then echo "Config missing!"; exit 1; fi

# BACA CONFIG
SWAP=$(jq -r '.setting_hp.enable_swap // true' $CONF)
TOTAL_ACC=$(jq '.accounts | length' $CONF)
DELAY=$(jq -r '.setting_waktu.rejoin_delay_detik // 1800' $CONF)

# SETUP SYSTEM (Background)
setup_system() {
    if [ "$SWAP" == "true" ] && [ ! -f /data/swapfile ]; then
        su -c "dd if=/dev/zero of=/data/swapfile bs=1M count=2048" >/dev/null 2>&1
        su -c "mkswap /data/swapfile" >/dev/null 2>&1
        su -c "swapon /data/swapfile" >/dev/null 2>&1
    fi
}

# START AKUN (Launch Sequence)
launch_sequence() {
    for ((i=0; i<$TOTAL_ACC; i++)); do
        PKG=$(jq -r ".accounts[$i].package" $CONF)
        LINK=$(jq -r ".accounts[$i].link" $CONF)
        
        # Launch diam-diam
        su -c "am force-stop $PKG" >/dev/null 2>&1
        su -c "am start -n $PKG/com.roblox.client.Activity -a android.intent.action.VIEW -d '$LINK'" >/dev/null 2>&1
        sleep 5
    done
}

# --- TAMPILAN DASHBOARD (THE TABLE) ---
draw_dashboard() {
    clear
    echo -e "${C}  ██████╗ ██╗██╗   ██╗██╗███╗   ██╗███████╗${N}"
    echo -e "${C}  ██╔══██╗██║██║   ██║██║████╗  ██║██╔════╝${N}"
    echo -e "${C}  ██████╔╝██║╚██╗ ██╔╝██║██║╚██╗██║█████╗  ${N}"
    echo -e "       ${Y}v3.1 - Auto Farm Dashboard${N}"
    echo ""
    
    # SYSTEM STATS
    MEM_FREE=$(free -m | awk '/Mem:/ {print $4}')
    echo -e "${C}+---------------------------+-------------------+${N}"
    echo -e "${C}| SYSTEM STATUS             | MEMORY FREE       |${N}"
    echo -e "${C}+---------------------------+-------------------+${N}"
    printf "| %-25s | %-17s |\n" "$(date +%H:%M:%S)" "${MEM_FREE} MB"
    echo -e "${C}+---------------------------+-------------------+${N}"
    echo ""

    # ACCOUNT TABLE HEADER
    echo -e "${C}+--------------------------------------+------------+${N}"
    echo -e "${C}| PACKAGE NAME                         | STATUS     |${N}"
    echo -e "${C}+--------------------------------------+------------+${N}"

    # LOOP ISI TABLE
    for ((i=0; i<$TOTAL_ACC; i++)); do
        PKG=$(jq -r ".accounts[$i].package" $CONF)
        NAME=$(jq -r ".accounts[$i].nama_clone // \"$PKG\"" $CONF)
        
        # Cek apakah aplikasi jalan (PID check)
        # Kita pakai pgrep. Kalau ada PID, berarti Online.
        PID=$(pgrep -f $PKG)
        
        if [ -n "$PID" ]; then
            STATUS="${G}Online${N}"
        else
            STATUS="${R}Offline${N}"
        fi
        
        # Print Row Table (Format Rapi)
        printf "| %-36s | %b      |\n" "${PKG:0:36}" "$STATUS"
    done
    echo -e "${C}+--------------------------------------+------------+${N}"
    echo -e "\n[CTRL+C] to Stop Tool"
}

# --- MAIN LOOP ---
setup_system
# Launch sekali di awal
echo "Launching accounts..."
launch_sequence

while true; do
    draw_dashboard
    # Refresh dashboard tiap 5 detik tanpa launch ulang
    # Launch ulang nanti handle pake timer logic terpisah atau cron
    sleep 5 
done