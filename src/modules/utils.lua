-- utils.lua
-- Utilities and Helper Functions Module for DIVINETOOLS

local M = {}
local ui = require("modules.ui")

-- Signal handling for CTRL+C
function M.setupSignalHandler()
    -- Try to use posix.signal if available
    local ok, signal = pcall(require, "posix.signal")
    if ok then
        signal.signal(signal.SIGINT, function()
            print("\n\n" .. ui.colors.yellow .. "[!] Received interrupt signal. Stopping gracefully..." .. ui.colors.reset)
            -- Perform cleanup
            M.cleanup()
            os.exit(0)
        end)
    else
        -- Fallback for non-posix systems
        print(ui.colors.yellow .. "[!] Signal handling limited. Use 'q' to quit." .. ui.colors.reset)
    end
end

-- Cleanup resources
function M.cleanup()
    print(ui.colors.cyan .. "[*] Cleaning up resources..." .. ui.colors.reset)
    
    -- Close any open files
    collectgarbage()
    
    -- Kill background processes if any
    os.execute("pkill -f 'divine_monitor' 2>/dev/null")
    
    print(ui.colors.green .. "[+] Cleanup completed." .. ui.colors.reset)
end

-- Deep merge tables
function M.tableMerge(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k] or false) == "table" then
                M.tableMerge(t1[k] or {}, t2[k] or {})
            else
                t1[k] = v
            end
        else
            t1[k] = v
        end
    end
    return t1
end

-- Check if table contains value
function M.tableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- Get table keys as array
function M.tableKeys(tbl)
    local keys = {}
    for k, _ in pairs(tbl) do
        table.insert(keys, k)
    end
    return keys
end

-- Filter table by function
function M.tableFilter(tbl, func)
    local filtered = {}
    for k, v in pairs(tbl) do
        if func(v, k) then
            filtered[k] = v
        end
    end
    return filtered
end

-- Execute command with timeout
function M.executeWithTimeout(cmd, timeout)
    timeout = timeout or 5  -- Default 5 seconds
    
    local handle = io.popen(cmd .. " 2>&1 & echo $!")
    if not handle then
        return false, "Failed to execute command"
    end
    
    local pid = handle:read("*a"):gsub("%s+", "")
    handle:close()
    
    -- Wait for command to complete or timeout
    local start_time = os.time()
    while os.time() - start_time < timeout do
        local check = io.popen("ps -p " .. pid .. " > /dev/null 2>&1; echo $?")
        local status = check:read("*a"):gsub("%s+", "")
        check:close()
        
        if status == "1" then  -- Process finished
            return true, "Command completed"
        end
        
        -- Small delay to prevent CPU hogging
        os.execute("sleep 0.1")
    end
    
    -- Timeout reached, kill process
    os.execute("kill -9 " .. pid .. " 2>/dev/null")
    return false, "Command timeout after " .. timeout .. " seconds"
end

-- Safe file read
function M.readFile(path)
    local file = io.open(path, "r")
    if not file then
        return nil, "File not found: " .. path
    end
    
    local content = file:read("*a")
    file:close()
    return content
end

-- Safe file write
function M.writeFile(path, content)
    -- Create directory if it doesn't exist
    local dir = path:match("^(.*)/[^/]*$")
    if dir then
        os.execute("mkdir -p " .. dir .. " 2>/dev/null")
    end
    
    local file = io.open(path, "w")
    if not file then
        return false, "Cannot write to file: " .. path
    end
    
    file:write(content)
    file:close()
    return true
end

-- Check if file exists
function M.fileExists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- Get file size
function M.getFileSize(path)
    local file = io.open(path, "r")
    if not file then return 0 end
    
    local size = file:seek("end")
    file:close()
    return size
end

-- Create backup of file
function M.backupFile(path)
    if not M.fileExists(path) then
        return false, "File does not exist"
    end
    
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local backup_path = path .. ".backup_" .. timestamp
    
    local success, err = os.rename(path, backup_path)
    if success then
        return true, backup_path
    else
        return false, err
    end
end

-- Generate random string
function M.randomString(length)
    length = length or 8
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local result = ""
    
    for i = 1, length do
        local rand = math.random(1, #chars)
        result = result .. chars:sub(rand, rand)
    end
    
    return result
end

-- Validate URL
function M.isValidURL(url)
    if not url or url == "" then
        return false
    end
    
    -- Simple URL validation
    local pattern = "^(https?://[%w-_%.%?%.:/%+=&]+)$"
    return url:match(pattern) ~= nil
end

-- Validate package name
function M.isValidPackage(pkg)
    if not pkg or pkg == "" then
        return false
    end
    
    -- Android package name pattern
    local pattern = "^[a-zA-Z][a-zA-Z0-9_]*(%.[a-zA-Z][a-zA-Z0-9_]*)+$"
    return pkg:match(pattern) ~= nil
end

-- Execute command and capture output
function M.captureCommand(cmd)
    local handle = io.popen(cmd .. " 2>&1")
    if not handle then
        return nil
    end
    
    local output = handle:read("*a")
    handle:close()
    return output
end

-- Check if command exists
function M.commandExists(cmd)
    local result = M.captureCommand("command -v " .. cmd .. " 2>/dev/null")
    return result and result ~= ""
end

-- Check root access
function M.isRootAvailable()
    local result = M.captureCommand("su -c 'echo ROOT_TEST' 2>&1")
    return result and result:match("ROOT_TEST") ~= nil
end

-- Get Android version
function M.getAndroidVersion()
    local result = M.captureCommand("getprop ro.build.version.release")
    if result then
        return result:gsub("[\r\n]", "")
    end
    return "Unknown"
end

-- Get device model
function M.getDeviceModel()
    local result = M.captureCommand("getprop ro.product.model")
    if result then
        return result:gsub("[\r\n]", "")
    end
    return "Unknown"
end

-- Check if package is installed
function M.isPackageInstalled(pkg)
    local result = M.captureCommand("pm list packages | grep -w " .. pkg)
    return result and result:match("package:" .. pkg .. "$") ~= nil
end

-- Get package info
function M.getPackageInfo(pkg)
    if not M.isPackageInstalled(pkg) then
        return nil, "Package not installed"
    end
    
    local info = {}
    
    -- Get version
    local version = M.captureCommand("dumpsys package " .. pkg .. " | grep versionName")
    if version then
        info.version = version:match("versionName=(.-)%s") or "Unknown"
    end
    
    -- Get install path
    local path = M.captureCommand("pm path " .. pkg)
    if path then
        info.path = path:match("package:(.-)\n") or "Unknown"
    end
    
    -- Get install date
    local date = M.captureCommand("dumpsys package " .. pkg .. " | grep firstInstallTime")
    if date then
        local timestamp = date:match("firstInstallTime=(%d+)")
        if timestamp then
            info.install_date = os.date("%Y-%m-%d %H:%M:%S", timestamp / 1000)
        end
    end
    
    -- Get UID
    local uid = M.captureCommand("dumpsys package " .. pkg .. " | grep userId")
    if uid then
        info.uid = uid:match("userId=(%d+)") or "Unknown"
    end
    
    return info
end

-- Format seconds to human readable time
function M.formatTime(seconds)
    if seconds < 60 then
        return string.format("%ds", seconds)
    elseif seconds < 3600 then
        local minutes = math.floor(seconds / 60)
        local secs = seconds % 60
        return string.format("%dm %ds", minutes, secs)
    else
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        return string.format("%dh %dm", hours, minutes)
    end
end

-- Calculate elapsed time
function M.elapsedTime(start_time)
    return os.time() - start_time
end

-- Create directory recursively
function M.createDirectory(path)
    return os.execute("mkdir -p " .. path .. " 2>/dev/null")
end

-- List files in directory
function M.listFiles(dir, pattern)
    local files = {}
    local handle = io.popen("find " .. dir .. " -maxdepth 1 -type f -name '" .. (pattern or "*") .. "' 2>/dev/null")
    
    if handle then
        for line in handle:lines() do
            table.insert(files, line)
        end
        handle:close()
    end
    
    return files
end

-- Remove directory recursively
function M.removeDirectory(path)
    return os.execute("rm -rf " .. path .. " 2>/dev/null")
end

-- Copy file or directory
function M.copy(source, destination)
    return os.execute("cp -r " .. source .. " " .. destination .. " 2>/dev/null")
end

-- Move file or directory
function M.move(source, destination)
    return os.execute("mv " .. source .. " " .. destination .. " 2>/dev/null")
end

-- Get current timestamp
function M.getTimestamp()
    return os.time()
end

-- Format timestamp to readable date
function M.formatTimestamp(timestamp, format)
    format = format or "%Y-%m-%d %H:%M:%S"
    return os.date(format, timestamp)
end

-- Sleep for seconds (with message)
function M.sleep(seconds, message)
    if message then
        ui.showLoading(message, seconds)
    else
        local handle = io.popen("sleep " .. seconds)
        handle:close()
    end
end

-- Retry function with exponential backoff
function M.retry(func, max_attempts, base_delay)
    max_attempts = max_attempts or 3
    base_delay = base_delay or 1
    
    for attempt = 1, max_attempts do
        local success, result = pcall(func)
        
        if success then
            return true, result
        end
        
        if attempt < max_attempts then
            local delay = base_delay * (2 ^ (attempt - 1))  -- Exponential backoff
            print(ui.colors.yellow .. string.format("[!] Attempt %d failed. Retrying in %d seconds...", 
                  attempt, delay) .. ui.colors.reset)
            M.sleep(delay)
        end
    end
    
    return false, "Max retry attempts reached"
end

-- Create unique ID
function M.createUUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return template:gsub('[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

-- Truncate string with ellipsis
function M.truncate(str, max_len)
    if #str <= max_len then
        return str
    end
    return str:sub(1, max_len - 3) .. "..."
end

-- Escape shell arguments
function M.escapeShellArg(arg)
    return "'" .. tostring(arg):gsub("'", "'\"'\"'") .. "'"
end

-- Check internet connectivity
function M.checkInternet()
    local success = os.execute("ping -c 1 -W 1 8.8.8.8 > /dev/null 2>&1")
    return success == 0 or success == true
end

-- Get external IP address
function M.getExternalIP()
    local ip = M.captureCommand("curl -s ifconfig.me")
    if ip and ip ~= "" then
        return ip:gsub("[\r\n]", "")
    end
    
    -- Fallback
    ip = M.captureCommand("curl -s icanhazip.com")
    if ip and ip ~= "" then
        return ip:gsub("[\r\n]", "")
    end
    
    return nil
end

-- Calculate MD5 hash (requires md5sum command)
function M.calculateMD5(path)
    if not M.fileExists(path) then
        return nil
    end
    
    local result = M.captureCommand("md5sum " .. path .. " 2>/dev/null | awk '{print $1}'")
    if result then
        return result:gsub("[\r\n]", "")
    end
    return nil
end

-- Compress directory to zip
function M.compressToZip(source_dir, zip_file)
    return os.execute("cd " .. source_dir .. " && zip -r " .. zip_file .. " . > /dev/null 2>&1")
end

-- Extract zip file
function M.extractZip(zip_file, dest_dir)
    M.createDirectory(dest_dir)
    return os.execute("unzip -o " .. zip_file .. " -d " .. dest_dir .. " > /dev/null 2>&1")
end

-- Log message to file
function M.log(message, level, log_file)
    log_file = log_file or "logs/divinetools.log"
    
    -- Create logs directory if it doesn't exist
    M.createDirectory("logs")
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local level_str = level or "INFO"
    
    local log_entry = string.format("[%s] [%s] %s\n", timestamp, level_str, message)
    
    local file = io.open(log_file, "a")
    if file then
        file:write(log_entry)
        file:close()
    end
end

-- Performance timer
M.PerformanceTimer = {}
M.PerformanceTimer.__index = M.PerformanceTimer

function M.PerformanceTimer:new()
    local obj = { start_time = os.time() }
    setmetatable(obj, M.PerformanceTimer)
    return obj
end

function M.PerformanceTimer:elapsed()
    return os.time() - self.start_time
end

function M.PerformanceTimer:reset()
    self.start_time = os.time()
end

function M.PerformanceTimer:lap()
    local elapsed = self:elapsed()
    self:reset()
    return elapsed
end

-- Memory usage monitor
function M.getMemoryUsage()
    local mem_info = M.captureCommand("cat /proc/meminfo 2>/dev/null")
    if not mem_info then
        return nil
    end
    
    local mem_total = mem_info:match("MemTotal:%s+(%d+)")
    local mem_free = mem_info:match("MemFree:%s+(%d+)")
    local mem_available = mem_info:match("MemAvailable:%s+(%d+)")
    
    if mem_total and mem_available then
        local total_kb = tonumber(mem_total)
        local available_kb = tonumber(mem_available)
        local used_kb = total_kb - available_kb
        local percent = (used_kb / total_kb) * 100
        
        return {
            total = total_kb,
            used = used_kb,
            available = available_kb,
            percent = percent,
            human = string.format("%.1f/%.1f MB (%.1f%%)", 
                   used_kb/1024, total_kb/1024, percent)
        }
    end
    
    return nil
end

-- CPU usage monitor
function M.getCPUUsage()
    local stat1 = M.captureCommand("cat /proc/stat | grep '^cpu '")
    M.sleep(0.1)
    local stat2 = M.captureCommand("cat /proc/stat | grep '^cpu '")
    
    if not stat1 or not stat2 then
        return nil
    end
    
    -- Parse CPU stats
    local function parse_cpu(line)
        local user, nice, system, idle = line:match("cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")
        return tonumber(user), tonumber(nice), tonumber(system), tonumber(idle)
    end
    
    local user1, nice1, system1, idle1 = parse_cpu(stat1)
    local user2, nice2, system2, idle2 = parse_cpu(stat2)
    
    if not user1 or not user2 then
        return nil
    end
    
    local total1 = user1 + nice1 + system1 + idle1
    local total2 = user2 + nice2 + system2 + idle2
    
    local total_diff = total2 - total1
    local idle_diff = idle2 - idle1
    
    local usage = 100 * (1 - idle_diff / total_diff)
    
    return {
        percent = usage,
        human = string.format("%.1f%%", usage)
    }
end

-- Battery status
function M.getBatteryStatus()
    if not M.fileExists("/sys/class/power_supply/battery/capacity") then
        return nil
    end
    
    local capacity = M.readFile("/sys/class/power_supply/battery/capacity")
    local status = M.readFile("/sys/class/power_supply/battery/status")
    
    if capacity and status then
        capacity = tonumber(capacity:gsub("[\r\n]", ""))
        status = status:gsub("[\r\n]", "")
        
        return {
            capacity = capacity,
            status = status,
            human = string.format("%d%% (%s)", capacity, status)
        }
    end
    
    return nil
end

-- Check storage space
function M.getStorageInfo()
    local df_output = M.captureCommand("df -h /data 2>/dev/null")
    if not df_output then
        return nil
    end
    
    local total, used, available = df_output:match("(%S+)%s+(%S+)%s+(%S+)%s+%S+%s+%d+%%%s+/data")
    
    return {
        total = total,
        used = used,
        available = available,
        human = string.format("%s used, %s free", used, available)
    }
end

return M