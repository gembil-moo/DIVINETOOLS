#!/bin/bash

# Cek apakah TSU terinstall
if ! command -v tsu &> /dev/null
then
    echo "❌ TSU (Root) belum terinstall!"
    echo "Jalankan 'bash install.sh' dulu."
    exit
fi

echo "🚀 Requesting Root Access..."
echo "⚠️  KLIK 'GRANT' / 'IZINKAN' DI POPUP!"

# Jalankan main.lua SEBAGAI ROOT (PENTING!)
tsu -c "lua main.lua"