#!/bin/bash

echo "💎 INSTALLING DIVINE TOOLS (LITE)..."

# 1. Setup Storage
termux-setup-storage

# 2. Update System
pkg update -y && pkg upgrade -y

# 3. Install Paket Wajib (Cukup ini aja)
# lua-cjson dari pkg jauh lebih stabil daripada luarocks
pkg install -y git lua54 lua-cjson curl tsu android-tools

# 4. Hapus folder config lama (reset) & buat baru
mkdir -p config

# 5. Izin Eksekusi
chmod +x run.sh

echo "✅ INSTALLATION SUCCESS!"
echo "Jalankan dengan perintah: bash run.sh"