#!/bin/bash

# DIVINETOOLS Launcher
# Version: 2.0.0

cd "$(dirname "$0")"

# Check if Lua is installed
if ! command -v lua5.3 &> /dev/null && ! command -v lua53 &> /dev/null && ! command -v lua &> /dev/null; then
    echo "[ERROR] Lua not found! Please run: bash install.sh"
    exit 1
fi

# Check for required Lua modules
LUA_TEST=$(lua5.3 -e "require('cjson')" 2>&1 || lua53 -e "require('cjson')" 2>&1 || lua -e "require('cjson')" 2>&1)
if [[ $LUA_TEST == *"module 'cjson' not found"* ]]; then
    echo "[ERROR] Lua module 'cjson' not installed!"
    echo "Run: luarocks install lua-cjson"
    exit 1
fi

# Create necessary directories
mkdir -p logs config

# Determine Lua executable
LUA_EXEC=""
for cmd in lua5.3 lua53 lua; do
    if command -v $cmd &> /dev/null; then
        LUA_EXEC=$cmd
        break
    fi
done

if [ -z "$LUA_EXEC" ]; then
    echo "[ERROR] No Lua interpreter found!"
    exit 1
fi

# Set log file
LOG_FILE="logs/divinetools_$(date +%Y%m%d_%H%M%S).log"

echo "========================================"
echo "   DIVINETOOLS v2.0 - Starting..."
echo "   Log: $LOG_FILE"
echo "========================================"

# Run main program
$LUA_EXEC src/main.lua 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -ne 0 ]; then
    echo "[ERROR] Program exited with code: $EXIT_CODE"
    echo "Check log file for details: $LOG_FILE"
fi

exit $EXIT_CODE