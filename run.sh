#!/bin/bash

# --- KONFIGURASI ---
# Ganti dengan link Private Server Abang
PRIVATE_SERVER="https://www.roblox.com/share?code=4aeaff16f909314387486bc9d29ed5d5&type=Server"

# Ganti sesuai nama package (contoh: com.roblox.client atau com.roblox.client.vip1)
PACKAGE_NAME="com.roblox.client" 

# Target Activity (Jantungnya Roblox)
ACTIVITY_NAME="com.roblox.client.Activity"

# --- FUNGSI OPTIMASI ---

# 1. Fungsi Swap File (Fitur "Dewa" buat Device Kentang)
check_and_create_swap() {
    echo "=== CEK VIRTUAL RAM (SWAP) ==="
    if [ ! -f /data/swapfile ]; then
        echo "[+] Membuat Swap File 2GB (Tunggu sebentar...)"
        # Membuat file 2GB
        su -c "dd if=/dev/zero of=/data/swapfile bs=1M count=2048"
        su -c "mkswap /data/swapfile"
        su -c "chmod 600 /data/swapfile"
    fi
    
    # Cek apakah swap aktif
    is_active=$(su -c "cat /proc/swaps | grep swapfile")
    if [ -z "$is_active" ]; then
        echo "[+] Mengaktifkan Swap..."
        su -c "swapon /data/swapfile"
        # Paksa prioritas tinggi ke swap
        su -c "echo 100 > /proc/sys/vm/swappiness" 
    else
        echo "[OK] Swap File sudah aktif."
    fi
}

# 2. Fungsi Boost Device Modern
boost_device() {
    echo "=== BOOSTING DEVICE ==="
    
    # Bersihkan Cache RAM
    su -c "sync; echo 3 > /proc/sys/vm/drop_caches"
    
    # Kill Aplikasi Pengganggu (Bloatware)
    # Tambahkan package lain di sini jika perlu
    local bloatware=("com.android.chrome" "com.google.android.youtube" "com.facebook.katana" "com.instagram.android")
    for app in "${bloatware[@]}"; do
        su -c "am force-stop $app > /dev/null 2>&1"
    done
    
    # LMK Tweak (Settingan Modern untuk 4GB+ RAM)
    # Format: VeryLow,Low,Normal,High,Critical,Die
    # Kita set angka tinggi biar Android galak bunuh background app
    echo "[+] Tuning Low Memory Killer..."
    su -c "echo '18432,23040,27648,32256,55296,80640' > /sys/module/lowmemorykiller/parameters/minfree"
    
    # CPU Performance Mode
    echo "[+] Set CPU ke Mode Tempur..."
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [ -f "$cpu" ]; then
            su -c "echo 'performance' > $cpu"
        fi
    done
}

# 3. Fungsi Launch Pintar (Bypass Browser)
launch_roblox() {
    echo "=== MELUNCURKAN ROBLOX ==="
    
    # Pastikan app mati dulu biar fresh (cegah memory leak)
    su -c "am force-stop $PACKAGE_NAME"
    sleep 1
    
    echo "[+] Injecting Link Server..."
    
    # COMMAND SAKTI (Gabungan -n dan -d)
    # -n : Memaksa buka package spesifik (Bypass 'Open With')
    # -d : Data link private server
    # -a : Action View
    
    su -c "am start -n $PACKAGE_NAME/$ACTIVITY_NAME -a android.intent.action.VIEW -d '$PRIVATE_SERVER'" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "[SUCCESS] Roblox diluncurkan ke Private Server!"
    else
        echo "[ERROR] Gagal launch. Cek Package Name: $PACKAGE_NAME"
    fi
}

# --- MAIN LOOP ---
main() {
    # Setup awal sekali jalan
    check_and_create_swap
    
    while true; do
        clear
        echo "=============================="
        echo "   AUTO FARM OPTIMIZER v2.0   "
        echo "=============================="
        echo "Waktu: $(date +%H:%M:%S)"
        
        # 1. Jalankan Optimasi
        boost_device
        
        # 2. Luncurkan Game
        launch_roblox
        
        # 3. Monitoring Loop
        echo ""
        echo "Game berjalan. Script akan refresh dalam 30 menit."
        echo "Tekan CTRL+C untuk stop."
        
        # Di sini kita sleep lama (misal 30 menit) karena auto-farm biasanya lama.
        # Kalau logic Abang mau rejoin tiap error, logicnya beda lagi.
        # Untuk sekarang saya set rejoin tiap 1800 detik (30 menit) preventif crash.
        sleep 1800 
    done
}

# Eksekusi
main