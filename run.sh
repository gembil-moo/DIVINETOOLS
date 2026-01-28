#!/bin/bash

# DIVINETOOLS Launcher
# Version: 2.0.0

cd "$(dirname "$0")"

echo "[INFO] Starting DIVINETOOLS..."
echo "[INFO] Working directory: $(pwd)"

# Check if Lua is installed
echo "[INFO] Checking for Lua interpreters..."

# Cari semua kemungkinan interpreter Lua
LUA_VARIANTS="lua5.4 lua54 lua5.3 lua53 lua5.2 lua52 lua5.1 lua51 lua"
LUA_EXEC=""

for cmd in $LUA_VARIANTS; do
    if command -v $cmd &> /dev/null; then
        echo "[INFO] Found: $cmd ($(which $cmd))"
        # Cek apakah punya module cjson
        if $cmd -e "require('cjson')" 2>/dev/null; then
            echo "[OK] $cmd has cjson module"
            LUA_EXEC=$cmd
            break
        else
            echo "[WARN] $cmd found but missing cjson module"
            # Coba cek versi Lua ini
            $cmd -v 2>/dev/null || echo "[WARN] Cannot get version for $cmd"
        fi
    fi
done

if [ -z "$LUA_EXEC" ]; then
    echo "=========================================="
    echo "[ERROR] No suitable Lua interpreter found!"
    echo "=========================================="
    echo ""
    echo "Possible solutions:"
    echo "1. Install Lua:"
    echo "   Ubuntu/Debian: sudo apt install lua5.3"
    echo "   CentOS/RHEL:   sudo yum install lua5.3"
    echo ""
    echo "2. Install cjson module:"
    echo "   sudo luarocks install lua-cjson"
    echo "   OR"
    echo "   Ubuntu/Debian: sudo apt install lua-cjson"
    echo ""
    echo "3. Check installed Lua versions:"
    echo "   ls /usr/bin/lua*"
    echo ""
    echo "4. Test manually:"
    echo "   lua -e \"require('cjson'); print('OK')\""
    exit 1
fi

echo "[INFO] Using Lua: $LUA_EXEC ($($LUA_EXEC -v 2>/dev/null || echo 'unknown version'))"

# Create necessary directories
mkdir -p logs config

# Set log file
LOG_FILE="logs/divinetools_$(date +%Y%m%d_%H%M%S).log"

echo "========================================"
echo "   DIVINETOOLS v2.0 - Starting..."
echo "   Lua: $LUA_EXEC"
echo "   Log: $LOG_FILE"
echo "========================================"

# Run main program
echo "[INFO] Executing: $LUA_EXEC src/main.lua"
$LUA_EXEC src/main.lua 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

echo "========================================"
echo "   Program finished"
echo "   Exit code: $EXIT_CODE"
echo "   Log file: $LOG_FILE"
echo "========================================"

if [ $EXIT_CODE -ne 0 ]; then
    echo "[ERROR] Program exited with code: $EXIT_CODE"
    echo "Check log file for details: $LOG_FILE"
    echo ""
    echo "Last 10 lines of log:"
    tail -10 "$LOG_FILE"
fi

exit $EXIT_CODE