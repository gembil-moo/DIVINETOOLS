-- uninstall.lua
-- Uninstall and Cleanup Module for DIVINETOOLS

local config = require("modules.config")
local ui = require("modules.ui")
local utils = require("modules.utils")
local backup = require("modules.backup")
local cjson = require("cjson")

local M = {}

-- Uninstall options
local UNINSTALL_OPTIONS = {
    FULL = {
        name = "Full Uninstall",
        description = "Remove everything: DIVINETOOLS and all related files",
        actions = {
            remove_program = true,
            remove_config = true,
            remove_scripts = true,
            remove_backups = false,  -- Keep backups by default
            remove_logs = true,
            remove_data = true
        }
    },
    PARTIAL = {
        name = "Partial Uninstall",
        description = "Remove program but keep configuration and scripts",
        actions = {
            remove_program = true,
            remove_config = false,
            remove_scripts = false,
            remove_backups = false,
            remove_logs = true,
            remove_data = true
        }
    },
    CLEAN = {
        name = "Cleanup Only",
        description = "Clean temporary files and logs only",
        actions = {
            remove_program = false,
            remove_config = false,
            remove_scripts = false,
            remove_backups = false,
            remove_logs = true,
            remove_data = true
        }
    },
    CUSTOM = {
        name = "Custom Uninstall",
        description = "Choose specific items to remove",
        actions = {}  -- Will be filled by user
    }
}

-- System directories to check for leftover files
local SYSTEM_DIRS = {
    "/data/data/com.termux/files/home/DIVINETOOLS",  -- Main installation
    "/storage/emulated/0/DivineBackups",            -- Backup directory
    "/storage/emulated/0/DivineScripts",            -- Custom scripts
    "/data/local/tmp/divine_*",                     -- Temporary files
    "/storage/emulated/0/Android/data/com.termux/files/home/DIVINETOOLS"  -- Alternate path
}

-- Uninstall statistics
local uninstall_stats = {
    start_time = nil,
    end_time = nil,
    files_removed = 0,
    dirs_removed = 0,
    total_size = 0,
    errors = 0
}

-- Initialize uninstall module
function M.initialize()
    print(ui.colors.cyan .. "[*] Initializing uninstall module..." .. ui.colors.reset)
    uninstall_stats.start_time = os.time()
    return true
end

-- Get uninstall statistics
function M.getStatistics()
    local stats = table.copy(uninstall_stats)
    stats.duration = os.time() - (uninstall_stats.start_time or os.time())
    return stats
end

-- Create backup before uninstall
function M.createPreUninstallBackup()
    print(ui.colors.yellow .. "[*] Creating pre-uninstall backup..." .. ui.colors.reset)
    
    local backup_result = backup.createBackup(
        backup.BACKUP_TYPES.FULL,
        backup.BACKUP_LOCATIONS.INTERNAL,
        backup.BACKUP_TYPES.FULL.includes,
        "Pre-uninstall backup"
    )
    
    if backup_result.success then
        print(ui.colors.green .. "[+] Pre-uninstall backup created successfully" .. ui.colors.reset)
        return backup_result.path
    else
        print(ui.colors.red .. "[!] Failed to create pre-uninstall backup" .. ui.colors.reset)
        return nil
    end
end

-- Remove program files
function M.removeProgramFiles()
    print(ui.colors.yellow .. "[*] Removing program files..." .. ui.colors.reset)
    
    local base_dir = utils.captureCommand("pwd"):gsub("[\r\n]", "")
    local removed = 0
    local size_freed = 0
    
    -- List of files and directories to remove
    local items_to_remove = {
        "src/",
        "install.sh",
        "run.sh",
        "requirements.txt",
        "config.example.json",
        "README.md",
        "LICENSE",
        ".git/",
        ".github/",
        "logs/",
        "docs/",
        "*.log",
        "*.tmp",
        "*.backup"
    }
    
    for _, item in ipairs(items_to_remove) do
        local cmd
        
        if item:match("/$") then  -- Directory
            cmd = string.format("rm -rf '%s/%s' 2>/dev/null", base_dir, item:gsub("/$", ""))
            local success = os.execute(cmd)
            if success then
                removed = removed + 1
                -- Try to calculate size (approximate)
                local size_cmd = string.format("du -sb '%s/%s' 2>/dev/null | cut -f1", base_dir, item:gsub("/$", ""))
                local size_result = utils.captureCommand(size_cmd)
                if size_result then
                    size_freed = size_freed + (tonumber(size_result:match("%d+")) or 0)
                end
            end
        else  -- File pattern
            cmd = string.format("find '%s' -name '%s' -type f -delete 2>/dev/null", base_dir, item)
            local success = os.execute(cmd)
            if success then
                removed = removed + 1
            end
        end
    end
    
    uninstall_stats.files_removed = uninstall_stats.files_removed + removed
    uninstall_stats.total_size = uninstall_stats.total_size + size_freed
    
    print(ui.colors.green .. string.format("[+] Removed %d program items", removed) .. ui.colors.reset)
    if size_freed > 0 then
        print(ui.colors.green .. string.format("[+] Freed %s", M.formatBytes(size_freed)) .. ui.colors.reset)
    end
    
    return removed, size_freed
end

-- Remove configuration files
function M.removeConfigFiles()
    print(ui.colors.yellow .. "[*] Removing configuration files..." .. ui.colors.reset)
    
    local removed = 0
    local size_freed = 0
    
    -- Remove config directory
    if utils.fileExists("config") then
        local size_cmd = "du -sb 'config' 2>/dev/null | cut -f1"
        local size_result = utils.captureCommand(size_cmd)
        
        local success = utils.removeDirectory("config")
        if success then
            removed = removed + 1
            uninstall_stats.dirs_removed = uninstall_stats.dirs_removed + 1
            
            if size_result then
                size_freed = tonumber(size_result:match("%d+")) or 0
                uninstall_stats.total_size = uninstall_stats.total_size + size_freed
            end
        end
    end
    
    -- Remove individual config files
    local config_files = {
        "config.json",
        "config.lua",
        "settings.json",
        "prefs.xml"
    }
    
    for _, file in ipairs(config_files) do
        if utils.fileExists(file) then
            local size = utils.getFileSize(file)
            os.execute("rm -f " .. utils.escapeShellArg(file))
            removed = removed + 1
            size_freed = size_freed + size
        end
    end
    
    print(ui.colors.green .. string.format("[+] Removed %d configuration items", removed) .. ui.colors.reset)
    if size_freed > 0 then
        print(ui.colors.green .. string.format("[+] Freed %s", M.formatBytes(size_freed)) .. ui.colors.reset)
    end
    
    return removed, size_freed
end

-- Remove script files
function M.removeScriptFiles()
    print(ui.colors.yellow .. "[*] Removing script files..." .. ui.colors.reset)
    
    local script_manager = require("modules.script_manager")
    local executors = script_manager.getAvailableExecutors()
    
    local removed = 0
    local size_freed = 0
    
    -- Remove scripts from all executors
    for _, executor in ipairs(executors) do
        local scripts = script_manager.listScripts(executor)
        
        for _, script in ipairs(scripts) do
            -- Check if it's a Divine script (starts with "Divine" or contains "divine")
            local script_name_lower = script.name:lower()
            if script_name_lower:match("divine") or script_name_lower:match("dvn") then
                local success, _ = script_manager.deleteScript(script.path)
                if success then
                    removed = removed + 1
                    size_freed = size_freed + (script.size or 0)
                end
            end
        end
        
        -- Remove empty executor directories
        local dir = script_manager.getScriptDir(executor)
        if executor == "Custom" then  -- Only remove custom directory if empty
            local files = utils.listFiles(dir, "*")
            if #files == 0 then
                utils.removeDirectory(dir)
                uninstall_stats.dirs_removed = uninstall_stats.dirs_removed + 1
            end
        end
    end
    
    uninstall_stats.files_removed = uninstall_stats.files_removed + removed
    uninstall_stats.total_size = uninstall_stats.total_size + size_freed
    
    print(ui.colors.green .. string.format("[+] Removed %d script files", removed) .. ui.colors.reset)
    if size_freed > 0 then
        print(ui.colors.green .. string.format("[+] Freed %s", M.formatBytes(size_freed)) .. ui.colors.reset)
    end
    
    return removed, size_freed
end

-- Remove backup files
function M.removeBackupFiles()
    print(ui.colors.yellow .. "[*] Removing backup files..." .. ui.colors.reset)
    
    local backup_location = backup.BACKUP_LOCATIONS.INTERNAL.path
    local removed = 0
    local size_freed = 0
    
    if utils.fileExists(backup_location) then
        -- Calculate total size before removal
        local size_cmd = string.format("du -sb '%s' 2>/dev/null | cut -f1", backup_location)
        local size_result = utils.captureCommand(size_cmd)
        
        -- Remove backup directory
        local success = utils.removeDirectory(backup_location)
        if success then
            removed = removed + 1
            uninstall_stats.dirs_removed = uninstall_stats.dirs_removed + 1
            
            if size_result then
                size_freed = tonumber(size_result:match("%d+")) or 0
                uninstall_stats.total_size = uninstall_stats.total_size + size_freed
            end
        end
    end
    
    -- Also check external backup location
    local external_location = backup.BACKUP_LOCATIONS.EXTERNAL.path
    if backup.BACKUP_LOCATIONS.EXTERNAL.accessible and utils.fileExists(external_location) then
        local success = utils.removeDirectory(external_location)
        if success then
            removed = removed + 1
            uninstall_stats.dirs_removed = uninstall_stats.dirs_removed + 1
        end
    end
    
    print(ui.colors.green .. string.format("[+] Removed %d backup locations", removed) .. ui.colors.reset)
    if size_freed > 0 then
        print(ui.colors.green .. string.format("[+] Freed %s", M.formatBytes(size_freed)) .. ui.colors.reset)
    end
    
    return removed, size_freed
end

-- Remove log files
function M.removeLogFiles()
    print(ui.colors.yellow .. "[*] Removing log files..." .. ui.colors.reset)
    
    local removed = 0
    local size_freed = 0
    
    -- Remove logs directory
    if utils.fileExists("logs") then
        local size_cmd = "du -sb 'logs' 2>/dev/null | cut -f1"
        local size_result = utils.captureCommand(size_cmd)
        
        local success = utils.removeDirectory("logs")
        if success then
            removed = removed + 1
            uninstall_stats.dirs_removed = uninstall_stats.dirs_removed + 1
            
            if size_result then
                size_freed = tonumber(size_result:match("%d+")) or 0
                uninstall_stats.total_size = uninstall_stats.total_size + size_freed
            end
        end
    end
    
    -- Remove individual log files
    local log_patterns = {
        "*.log",
        "*.txt",
        "error.*",
        "debug.*",
        "trace.*"
    }
    
    local base_dir = utils.captureCommand("pwd"):gsub("[\r\n]", "")
    
    for _, pattern in ipairs(log_patterns) do
        local cmd = string.format("find '%s' -name '%s' -type f -delete 2>/dev/null", base_dir, pattern)
        local success = os.execute(cmd)
        if success then
            removed = removed + 1
        end
    end
    
    uninstall_stats.files_removed = uninstall_stats.files_removed + removed
    uninstall_stats.total_size = uninstall_stats.total_size + size_freed
    
    print(ui.colors.green .. string.format("[+] Removed %d log items", removed) .. ui.colors.reset)
    if size_freed > 0 then
        print(ui.colors.green .. string.format("[+] Freed %s", M.formatBytes(size_freed)) .. ui.colors.reset)
    end
    
    return removed, size_freed
end

-- Remove data files
function M.removeDataFiles()
    print(ui.colors.yellow .. "[*] Removing data files..." .. ui.colors.reset)
    
    local removed = 0
    local size_freed = 0
    
    -- Remove data directory
    if utils.fileExists("data") then
        local size_cmd = "du -sb 'data' 2>/dev/null | cut -f1"
        local size_result = utils.captureCommand(size_cmd)
        
        local success = utils.removeDirectory("data")
        if success then
            removed = removed + 1
            uninstall_stats.dirs_removed = uninstall_stats.dirs_removed + 1
            
            if size_result then
                size_freed = tonumber(size_result:match("%d+")) or 0
                uninstall_stats.total_size = uninstall_stats.total_size + size_freed
            end
        end
    end
    
    -- Remove temporary files
    local temp_patterns = {
        "/data/local/tmp/divine_*",
        "/tmp/divine_*",
        "*.tmp",
        "*.temp",
        "*.cache"
    }
    
    for _, pattern in ipairs(temp_patterns) do
        local cmd = string.format("rm -rf %s 2>/dev/null", pattern)
        local success = os.execute(cmd)
        if success then
            removed = removed + 1
        end
    end
    
    uninstall_stats.files_removed = uninstall_stats.files_removed + removed
    uninstall_stats.total_size = uninstall_stats.total_size + size_freed
    
    print(ui.colors.green .. string.format("[+] Removed %d data items", removed) .. ui.colors.reset)
    if size_freed > 0 then
        print(ui.colors.green .. string.format("[+] Freed %s", M.formatBytes(size_freed)) .. ui.colors.reset)
    end
    
    return removed, size_freed
end

-- Clean up system files (advanced)
function M.cleanSystemFiles()
    print(ui.colors.yellow .. "[*] Cleaning system files..." .. ui.colors.reset)
    
    local removed = 0
    
    -- Check for leftover files in system directories
    for _, dir_pattern in ipairs(SYSTEM_DIRS) do
        local cmd = string.format("find %s -type f -name '*divine*' -o -name '*dvn*' 2>/dev/null", dir_pattern)
        local files = utils.captureCommand(cmd)
        
        if files then
            for file in files:gmatch("[^\n]+") do
                os.execute("rm -f " .. utils.escapeShellArg(file))
                removed = removed + 1
            end
        end
        
        -- Remove empty directories
        local dir_cmd = string.format("find %s -type d -empty -delete 2>/dev/null", dir_pattern)
        os.execute(dir_cmd)
    end
    
    uninstall_stats.files_removed = uninstall_stats.files_removed + removed
    
    print(ui.colors.green .. string.format("[+] Cleaned %d system files", removed) .. ui.colors.reset)
    return removed
end

-- Reset system optimizations
function M.resetSystemOptimizations()
    print(ui.colors.yellow .. "[*] Resetting system optimizations..." .. ui.colors.reset)
    
    -- Reset screen resolution
    os.execute("su -c 'wm size reset' 2>/dev/null")
    os.execute("su -c 'wm density reset' 2>/dev/null")
    
    -- Reset animations
    os.execute("su -c 'settings put global window_animation_scale 1' 2>/dev/null")
    os.execute("su -c 'settings put global transition_animation_scale 1' 2>/dev/null")
    os.execute("su -c 'settings put global animator_duration_scale 1' 2>/dev/null")
    
    -- Reset sounds
    os.execute("su -c 'settings put system sound_effects_enabled 1' 2>/dev/null")
    
    -- Reset low power mode
    os.execute("su -c 'settings put global low_power 0' 2>/dev/null")
    
    print(ui.colors.green .. "[+] System optimizations reset" .. ui.colors.reset)
    return true
end

-- Remove package dependencies (optional)
function M.removeDependencies(remove_all)
    print(ui.colors.yellow .. "[*] Removing dependencies..." .. ui.colors.reset)
    
    if not ui.confirm("Remove installed packages? This may break other applications.", ui.colors.red) then
        print(ui.colors.yellow .. "[*] Skipping dependency removal" .. ui.colors.reset)
        return 0
    end
    
    local removed = 0
    
    -- List of packages installed by DIVINETOOLS
    local dependencies = {
        "lua53",
        "luarocks",
        "python",
        "tsu",
        "figlet",
        "toilet",
        "ncurses-utils",
        "android-tools",
        "clang",
        "make",
        "lua-cjson",
        "luasocket"
    }
    
    for _, pkg in ipairs(dependencies) do
        -- Check if package is installed
        local check_cmd = string.format("pkg list-installed | grep -w %s 2>/dev/null", pkg)
        local installed = utils.captureCommand(check_cmd)
        
        if installed then
            if remove_all or ui.confirm("Remove " .. pkg .. "?", ui.colors.yellow) then
                local cmd = string.format("pkg uninstall -y %s 2>/dev/null", pkg)
                local success = os.execute(cmd)
                if success then
                    removed = removed + 1
                    print(ui.colors.green .. "  ✓ Removed: " .. pkg .. ui.colors.reset)
                else
                    print(ui.colors.red .. "  ✗ Failed: " .. pkg .. ui.colors.reset)
                    uninstall_stats.errors = uninstall_stats.errors + 1
                end
            end
        end
    end
    
    print(ui.colors.green .. string.format("[+] Removed %d dependencies", removed) .. ui.colors.reset)
    return removed
end

-- Format bytes for display
function M.formatBytes(bytes)
    if bytes < 1024 then
        return string.format("%d B", bytes)
    elseif bytes < 1024 * 1024 then
        return string.format("%.2f KB", bytes / 1024)
    elseif bytes < 1024 * 1024 * 1024 then
        return string.format("%.2f MB", bytes / (1024 * 1024))
    else
        return string.format("%.2f GB", bytes / (1024 * 1024 * 1024))
    end
end

-- Perform uninstall
function M.performUninstall(options, custom_actions)
    M.initialize()
    
    local actions = options.actions
    if options.name == "Custom Uninstall" and custom_actions then
        actions = custom_actions
    end
    
    print(ui.colors.cyan .. "\n🚀 STARTING UNINSTALL: " .. options.name .. ui.colors.reset)
    ui.printSeparator(60, "═", ui.colors.cyan)
    print(ui.colors.yellow .. "Description: " .. options.description .. ui.colors.reset)
    ui.printSeparator(60, "─", ui.colors.cyan)
    
    -- Ask for confirmation one more time
    if not ui.confirm(ui.colors.red .. "Are you ABSOLUTELY sure you want to continue?" .. ui.colors.reset, ui.colors.red) then
        print(ui.colors.yellow .. "[*] Uninstall cancelled by user" .. ui.colors.reset)
        return {success = false, cancelled = true}
    end
    
    -- Create backup if requested
    local backup_path = nil
    if ui.confirm("Create backup before uninstall?", ui.colors.yellow) then
        backup_path = M.createPreUninstallBackup()
    end
    
    -- Perform actions
    local results = {
        actions_performed = {},
        backup_created = backup_path,
        statistics = {}
    }
    
    if actions.remove_program then
        local count, size = M.removeProgramFiles()
        table.insert(results.actions_performed, {
            action = "remove_program",
            count = count,
            size = size
        })
    end
    
    if actions.remove_config then
        local count, size = M.removeConfigFiles()
        table.insert(results.actions_performed, {
            action = "remove_config",
            count = count,
            size = size
        })
    end
    
    if actions.remove_scripts then
        local count, size = M.removeScriptFiles()
        table.insert(results.actions_performed, {
            action = "remove_scripts",
            count = count,
            size = size
        })
    end
    
    if actions.remove_backups then
        local count, size = M.removeBackupFiles()
        table.insert(results.actions_performed, {
            action = "remove_backups",
            count = count,
            size = size
        })
    end
    
    if actions.remove_logs then
        local count, size = M.removeLogFiles()
        table.insert(results.actions_performed, {
            action = "remove_logs",
            count = count,
            size = size
        })
    end
    
    if actions.remove_data then
        local count, size = M.removeDataFiles()
        table.insert(results.actions_performed, {
            action = "remove_data",
            count = count,
            size = size
        })
    end
    
    -- Additional cleanup
    if options.name == "Full Uninstall" then
        M.cleanSystemFiles()
        M.resetSystemOptimizations()
        
        -- Ask about dependencies
        if ui.confirm("Remove installed dependencies?", ui.colors.yellow) then
            local removed = M.removeDependencies(true)
            table.insert(results.actions_performed, {
                action = "remove_dependencies",
                count = removed
            })
        end
    end
    
    -- Final statistics
    uninstall_stats.end_time = os.time()
    results.statistics = M.getStatistics()
    
    -- Show summary
    print(ui.colors.green .. "\n✅ UNINSTALL COMPLETED SUCCESSFULLY" .. ui.colors.reset)
    ui.printSeparator(60, "═", ui.colors.green)
    
    print(ui.colors.cyan .. "📊 Uninstall Statistics:" .. ui.colors.reset)
    print(string.format("  Files removed:    %d", uninstall_stats.files_removed))
    print(string.format("  Directories removed: %d", uninstall_stats.dirs_removed))
    print(string.format("  Total size freed: %s", M.formatBytes(uninstall_stats.total_size)))
    print(string.format("  Duration:         %d seconds", results.statistics.duration))
    print(string.format("  Errors:           %d", uninstall_stats.errors))
    
    if backup_path then
        print(string.format("  Backup created:   %s", backup_path))
    end
    
    ui.printSeparator(60, "═", ui.colors.green)
    
    -- Show what was removed
    if #results.actions_performed > 0 then
        print(ui.colors.yellow .. "Actions performed:" .. ui.colors.reset)
        for _, action in ipairs(results.actions_performed) do
            local size_str = action.size and M.formatBytes(action.size) or "N/A"
            print(string.format("  ✓ %-20s: %d items (%s)", 
                  action.action:gsub("_", " "), action.count or 0, size_str))
        end
    end
    
    -- Final message
    print("\n" .. ui.colors.red .. "⚠️  IMPORTANT: " .. ui.colors.reset)
    print(ui.colors.yellow .. "  - DIVINETOOLS has been removed from your system" .. ui.colors.reset)
    print(ui.colors.yellow .. "  - You may need to restart Termux for changes to take full effect" .. ui.colors.reset)
    
    if backup_path then
        print(ui.colors.yellow .. "  - A backup was created at: " .. backup_path .. ui.colors.reset)
        print(ui.colors.yellow .. "  - You can restore from this backup if needed" .. ui.colors.reset)
    end
    
    print("\n" .. ui.colors.cyan .. "Thank you for using DIVINETOOLS! 👋" .. ui.colors.reset)
    
    results.success = true
    return results
end

-- Show uninstall menu
function M.showMenu()
    while true do
        ui.clearScreen()
        ui.printSeparator(54, "═", ui.colors.red)
        print("        " .. ui.colors.red .. "✦ UNINSTALL DIVINETOOLS ✦" .. ui.colors.reset)
        ui.printSeparator(54, "═", ui.colors.red)
        
        print(ui.colors.yellow .. "⚠️  WARNING: This will remove DIVINETOOLS from your system" .. ui.colors.reset)
        print(ui.colors.yellow .. "   Some operations cannot be undone!" .. ui.colors.reset)
        
        ui.printSeparator(54, "─", ui.colors.yellow)
        
        print(ui.colors.cyan .. "  [1] Full Uninstall" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. UNINSTALL_OPTIONS.FULL.description .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [2] Partial Uninstall" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. UNINSTALL_OPTIONS.PARTIAL.description .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [3] Cleanup Only" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. UNINSTALL_OPTIONS.CLEAN.description .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [4] Custom Uninstall" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. UNINSTALL_OPTIONS.CUSTOM.description .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [5] View Disk Usage" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "See how much space DIVINETOOLS is using" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [6] Back to Main Menu" .. ui.colors.reset)
        
        ui.printSeparator(54, "═", ui.colors.red)
        
        local choice = ui.getNumberInput("\nSelect option (1-6): ", 1, 6)
        
        if choice == 1 then
            M.confirmAndUninstall(UNINSTALL_OPTIONS.FULL)
            break  -- Exit after uninstall
            
        elseif choice == 2 then
            M.confirmAndUninstall(UNINSTALL_OPTIONS.PARTIAL)
            break  -- Exit after uninstall
            
        elseif choice == 3 then
            M.confirmAndUninstall(UNINSTALL_OPTIONS.CLEAN)
            -- Don't break, allow returning to menu
            
        elseif choice == 4 then
            M.customUninstallMenu()
            -- Don't break, allow returning to menu
            
        elseif choice == 5 then
            M.showDiskUsage()
            
        elseif choice == 6 then
            break
        end
        
        if choice ~= 1 and choice ~= 2 then  -- Don't pause if we're exiting
            ui.pressToContinue()
        end
    end
end

-- Confirm and execute uninstall
function M.confirmAndUninstall(options)
    ui.clearScreen()
    ui.printSeparator(60, "═", ui.colors.red)
    print("        " .. ui.colors.red .. "CONFIRM UNINSTALL: " .. options.name .. ui.colors.reset)
    ui.printSeparator(60, "═", ui.colors.red)
    
    print(ui.colors.yellow .. "You are about to perform: " .. ui.colors.reset)
    print(ui.colors.cyan .. "  " .. options.name .. ui.colors.reset)
    print(ui.colors.yellow .. "  " .. options.description .. ui.colors.reset)
    
    print("\n" .. ui.colors.red .. "This will perform the following actions:" .. ui.colors.reset)
    for action, enabled in pairs(options.actions) do
        if enabled then
            print(ui.colors.yellow .. "  ✓ " .. action:gsub("_", " ") .. ui.colors.reset)
        end
    end
    
    print("\n" .. ui.colors.red .. "⚠️  THIS ACTION IS IRREVERSIBLE!" .. ui.colors.reset)
    print(ui.colors.red .. "   Some files may be permanently deleted." .. ui.colors.reset)
    
    ui.printSeparator(60, "═", ui.colors.red)
    
    local confirm_text = "Type 'UNINSTALL' to confirm: "
    io.write(ui.colors.red .. confirm_text .. ui.colors.reset)
    local confirmation = io.read()
    
    if confirmation:upper() ~= "UNINSTALL" then
        print(ui.colors.yellow .. "\n[*] Uninstall cancelled" .. ui.colors.reset)
        ui.pressToContinue()
        return
    end
    
    -- One more confirmation for destructive operations
    if options.name == "Full Uninstall" then
        if not ui.confirm(ui.colors.red .. "FINAL WARNING: This will delete ALL DIVINETOOLS files. Continue?" .. ui.colors.reset, ui.colors.red) then
            print(ui.colors.yellow .. "\n[*] Uninstall cancelled" .. ui.colors.reset)
            ui.pressToContinue()
            return
        end
    end
    
    -- Perform uninstall
    local result = M.performUninstall(options)
    
    if result.success then
        -- Wait a moment before potentially exiting
        utils.sleep(3)
        
        -- If it was a full or partial uninstall, exit the program
        if options.name == "Full Uninstall" or options.name == "Partial Uninstall" then
            print(ui.colors.cyan .. "\n[*] Exiting DIVINETOOLS..." .. ui.colors.reset)
            utils.sleep(2)
            os.exit(0)
        end
    end
end

-- Custom uninstall menu
function M.customUninstallMenu()
    ui.clearScreen()
    ui.printSeparator(54, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "✦ CUSTOM UNINSTALL ✦" .. ui.colors.reset)
    ui.printSeparator(54, "═", ui.colors.cyan)
    
    print(ui.colors.yellow .. "Select items to remove:" .. ui.colors.reset)
    print()
    
    local actions = {}
    local options = {
        {"Program files", "remove_program", "DIVINETOOLS program files and binaries"},
        {"Configuration", "remove_config", "All configuration files and settings"},
        {"Scripts", "remove_scripts", "Script files injected by DIVINETOOLS"},
        {"Backups", "remove_backups", "Backup files created by DIVINETOOLS"},
        {"Log files", "remove_logs", "Log files and debugging information"},
        {"Data files", "remove_data", "Temporary data and cache files"},
        {"System optimizations", "reset_optimizations", "Reset system settings to default"}
    }
    
    for i, option in ipairs(options) do
        print(string.format("  [%d] %s", i, option[1]))
        print("      " .. ui.colors.cyan .. option[3] .. ui.colors.reset)
    end
    
    print()
    io.write(ui.colors.yellow .. "Enter selections (e.g., 1,3,5 or 'all'): " .. ui.colors.reset)
    local input = io.read():gsub("%s+", "")
    
    if input:lower() == "all" then
        for _, option in ipairs(options) do
            actions[option[2]] = true
        end
    else
        for str in input:gmatch("[^,]+") do
            local idx = tonumber(str)
            if idx and idx >= 1 and idx <= #options then
                actions[options[idx][2]] = true
            end
        end
    end
    
    if next(actions) == nil then
        ui.showMessage("No items selected for removal", "warning")
        return
    end
    
    -- Create custom options
    local custom_options = {
        name = "Custom Uninstall",
        description = "User-selected items removal",
        actions = actions
    }
    
    M.confirmAndUninstall(custom_options)
end

-- Show disk usage
function M.showDiskUsage()
    ui.clearScreen()
    ui.printSeparator(54, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "✦ DISK USAGE ANALYSIS ✦" .. ui.colors.reset)
    ui.printSeparator(54, "═", ui.colors.cyan)
    
    print(ui.colors.yellow .. "Analyzing DIVINETOOLS disk usage..." .. ui.colors.reset)
    
    local directories = {
        {"Program Files", "."},
        {"Configuration", "config"},
        {"Scripts", "/storage/emulated/0/DivineScripts"},
        {"Backups", backup.BACKUP_LOCATIONS.INTERNAL.path},
        {"Logs", "logs"},
        {"Data", "data"}
    }
    
    local total_size = 0
    local results = {}
    
    for _, dir_info in ipairs(directories) do
        local name, path = dir_info[1], dir_info[2]
        
        if utils.fileExists(path) then
            local size = M.calculateSize(path)
            total_size = total_size + size
            
            table.insert(results, {
                name = name,
                path = path,
                size = size,
                formatted = M.formatBytes(size)
            })
        end
    end
    
    -- Display results
    if #results > 0 then
        ui.printSeparator(60, "─", ui.colors.yellow)
        
        local headers = {"Directory", "Size", "Path"}
        local rows = {}
        
        for _, result in ipairs(results) do
            local display_path = result.path
            if #display_path > 30 then
                display_path = "..." .. display_path:sub(-27)
            end
            
            table.insert(rows, {
                result.name,
                result.formatted,
                display_path
            })
        end
        
        ui.displayTable(headers, rows, "Disk Usage Breakdown")
        
        print(ui.colors.cyan .. "\n📊 Total Disk Usage: " .. M.formatBytes(total_size) .. ui.colors.reset)
        
        -- Show percentage of free space
        local free_space = M.getFreeSpace(".")
        print(ui.colors.cyan .. "💾 Free Space: " .. free_space .. ui.colors.reset)
        
    else
        print(ui.colors.yellow .. "\nNo DIVINETOOLS directories found." .. ui.colors.reset)
    end
    
    ui.printSeparator(54, "═", ui.colors.cyan)
end

-- Get free space
function M.getFreeSpace(path)
    local cmd = string.format("df '%s' 2>/dev/null | tail -1 | awk '{print $4}'", path)
    local result = utils.captureCommand(cmd)
    
    if result then
        local kb = tonumber(result:match("%d+"))
        if kb then
            if kb > 1024 * 1024 then  -- > GB
                return string.format("%.2f GB", kb / (1024 * 1024))
            elseif kb > 1024 then  -- > MB
                return string.format("%.2f MB", kb / 1024)
            else
                return string.format("%d KB", kb)
            end
        end
    end
    
    return "Unknown"
end

-- Table copy helper
function table.copy(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

return M