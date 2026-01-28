-- backup.lua
-- Backup and Restore Module for DIVINETOOLS

local config = require("modules.config")
local ui = require("modules.ui")
local utils = require("modules.utils")
local cjson = require("cjson")
local zip = require("zip")  -- Lua-zip if available, otherwise use os commands

local M = {}

-- Backup types
local BACKUP_TYPES = {
    FULL = {
        name = "Full Backup",
        description = "Backup everything: config, scripts, logs, and data",
        includes = {"config", "scripts", "logs", "data", "modules"}
    },
    CONFIG = {
        name = "Configuration Only",
        description = "Backup only configuration files",
        includes = {"config"}
    },
    SCRIPTS = {
        name = "Scripts Only",
        description = "Backup only script files",
        includes = {"scripts"}
    },
    SELECTIVE = {
        name = "Selective Backup",
        description = "Choose specific items to backup",
        includes = {}  -- Will be filled by user
    }
}

-- Backup locations
local BACKUP_LOCATIONS = {
    INTERNAL = {
        name = "Internal Storage",
        path = "/storage/emulated/0/DivineBackups",
        accessible = true
    },
    EXTERNAL = {
        name = "External SD Card",
        path = "/storage/sdcard1/DivineBackups",
        accessible = false  -- Will be checked
    },
    CUSTOM = {
        name = "Custom Location",
        path = "",
        accessible = false
    }
}

-- Current backup state
local backup_state = {
    last_backup = nil,
    last_restore = nil,
    backup_count = 0,
    total_size = 0
}

-- Initialize backup module
function M.initialize()
    print(ui.colors.cyan .. "[*] Initializing backup module..." .. ui.colors.reset)
    
    -- Create default backup directory
    utils.createDirectory(BACKUP_LOCATIONS.INTERNAL.path)
    
    -- Check external storage accessibility
    BACKUP_LOCATIONS.EXTERNAL.accessible = M.checkPathAccessible(BACKUP_LOCATIONS.EXTERNAL.path)
    
    -- Load backup state if exists
    M.loadBackupState()
    
    print(ui.colors.green .. "[+] Backup module initialized" .. ui.colors.reset)
    print(ui.colors.yellow .. "    Default location: " .. BACKUP_LOCATIONS.INTERNAL.path .. ui.colors.reset)
end

-- Check if path is accessible
function M.checkPathAccessible(path)
    local cmd = string.format("test -d '%s' 2>/dev/null && echo 'accessible'", path)
    local result = utils.captureCommand(cmd)
    return result and result:match("accessible") ~= nil
end

-- Load backup state from file
function M.loadBackupState()
    local state_file = BACKUP_LOCATIONS.INTERNAL.path .. "/backup_state.json"
    local content = utils.readFile(state_file)
    
    if content then
        local success, state = pcall(cjson.decode, content)
        if success and state then
            backup_state = state
            return true
        end
    end
    
    return false
end

-- Save backup state to file
function M.saveBackupState()
    local state_file = BACKUP_LOCATIONS.INTERNAL.path .. "/backup_state.json"
    local content = cjson.encode(backup_state)
    return utils.writeFile(state_file, content)
end

-- Get backup statistics
function M.getStatistics()
    local stats = {
        total_backups = backup_state.backup_count,
        last_backup = backup_state.last_backup,
        last_restore = backup_state.last_restore,
        total_size = backup_state.total_size,
        free_space = M.getFreeSpace(BACKUP_LOCATIONS.INTERNAL.path)
    }
    
    return stats
end

-- Get free space at location
function M.getFreeSpace(path)
    local cmd = string.format("df '%s' 2>/dev/null | tail -1 | awk '{print $4}'", path)
    local result = utils.captureCommand(cmd)
    
    if result then
        local kb = tonumber(result:match("%d+"))
        if kb then
            if kb > 1024 * 1024 then  > GB
                return string.format("%.2f GB", kb / (1024 * 1024))
            elseif kb > 1024 then  > MB
                return string.format("%.2f MB", kb / 1024)
            else
                return string.format("%d KB", kb)
            end
        end
    end
    
    return "Unknown"
end

-- Calculate directory size
function M.calculateSize(path)
    local cmd = string.format("du -sb '%s' 2>/dev/null | cut -f1", path)
    local result = utils.captureCommand(cmd)
    
    if result then
        local bytes = tonumber(result:match("%d+"))
        return bytes or 0
    end
    
    return 0
end

-- Create backup
function M.createBackup(backup_type, location, items, comment)
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local backup_name = string.format("divine_backup_%s_%s", 
        backup_type.name:lower():gsub(" ", "_"), timestamp)
    
    local backup_path = location.path .. "/" .. backup_name
    
    print(ui.colors.cyan .. "\n📦 CREATING BACKUP: " .. backup_type.name .. ui.colors.reset)
    ui.printSeparator(50, "─", ui.colors.cyan)
    
    -- Create backup directory
    utils.createDirectory(backup_path)
    
    -- Backup manifest
    local manifest = {
        name = backup_name,
        type = backup_type.name,
        timestamp = os.time(),
        date = os.date("%Y-%m-%d %H:%M:%S"),
        comment = comment or "",
        version = "2.0",
        items = {}
    }
    
    local total_size = 0
    local item_count = 0
    
    -- Backup config files
    if utils.tableContains(items, "config") or backup_type.name == "FULL" then
        ui.showLoading("Backing up configuration", 1)
        
        local config_dir = backup_path .. "/config"
        utils.createDirectory(config_dir)
        
        -- Copy config files
        local config_files = utils.listFiles("config", "*")
        for _, file in ipairs(config_files) do
            local dest = config_dir .. "/" .. file:match("([^/]+)$")
            if utils.copy(file, dest) then
                total_size = total_size + utils.getFileSize(file)
                item_count = item_count + 1
            end
        end
        
        table.insert(manifest.items, {
            type = "config",
            count = #config_files,
            size = M.calculateSize(config_dir)
        })
    end
    
    -- Backup scripts
    if utils.tableContains(items, "scripts") or backup_type.name == "FULL" then
        ui.showLoading("Backing up scripts", 2)
        
        local scripts_dir = backup_path .. "/scripts"
        utils.createDirectory(scripts_dir)
        
        -- Get all scripts from all executors
        local script_manager = require("modules.script_manager")
        local executors = script_manager.getAvailableExecutors()
        
        local script_count = 0
        for _, executor in ipairs(executors) do
            local scripts = script_manager.listScripts(executor)
            for _, script in ipairs(scripts) do
                local dest_dir = scripts_dir .. "/" .. executor
                utils.createDirectory(dest_dir)
                
                local dest = dest_dir .. "/" .. script.name
                if utils.copy(script.path, dest) then
                    total_size = total_size + script.size
                    script_count = script_count + 1
                end
            end
        end
        
        table.insert(manifest.items, {
            type = "scripts",
            count = script_count,
            executors = executors
        })
    end
    
    -- Backup logs
    if utils.tableContains(items, "logs") or backup_type.name == "FULL" then
        ui.showLoading("Backing up logs", 1)
        
        local logs_dir = backup_path .. "/logs"
        utils.createDirectory(logs_dir)
        
        local log_files = utils.listFiles("logs", "*")
        for _, file in ipairs(log_files) do
            local dest = logs_dir .. "/" .. file:match("([^/]+)$")
            if utils.copy(file, dest) then
                total_size = total_size + utils.getFileSize(file)
                item_count = item_count + 1
            end
        end
        
        table.insert(manifest.items, {
            type = "logs",
            count = #log_files,
            size = M.calculateSize(logs_dir)
        })
    end
    
    -- Backup data
    if utils.tableContains(items, "data") or backup_type.name == "FULL" then
        ui.showLoading("Backing up data files", 1)
        
        local data_dir = backup_path .. "/data"
        utils.createDirectory(data_dir)
        
        -- Check for any data files
        if utils.fileExists("data") then
            utils.copy("data", data_dir)
            total_size = total_size + M.calculateSize("data")
        end
        
        table.insert(manifest.items, {
            type = "data",
            size = M.calculateSize(data_dir)
        })
    end
    
    -- Save manifest
    manifest.total_size = total_size
    manifest.item_count = item_count
    
    local manifest_file = backup_path .. "/manifest.json"
    utils.writeFile(manifest_file, cjson.encode(manifest))
    
    -- Create zip archive
    ui.showLoading("Creating backup archive", 2)
    
    local zip_file = location.path .. "/" .. backup_name .. ".zip"
    local zip_success = utils.compressToZip(backup_path, zip_file)
    
    -- Cleanup temporary directory
    utils.removeDirectory(backup_path)
    
    if not zip_success then
        -- If zip fails, keep the directory
        zip_file = backup_path
    end
    
    -- Update backup state
    backup_state.last_backup = os.time()
    backup_state.backup_count = backup_state.backup_count + 1
    backup_state.total_size = backup_state.total_size + total_size
    M.saveBackupState()
    
    -- Show summary
    print(ui.colors.green .. "\n✅ BACKUP CREATED SUCCESSFULLY" .. ui.colors.reset)
    ui.printSeparator(50, "─", ui.colors.green)
    
    print(ui.colors.cyan .. "  Name:      " .. backup_name .. ui.colors.reset)
    print(ui.colors.cyan .. "  Type:      " .. backup_type.name .. ui.colors.reset)
    print(ui.colors.cyan .. "  Location:  " .. location.path .. ui.colors.reset)
    print(ui.colors.cyan .. "  Size:      " .. M.formatBytes(total_size) .. ui.colors.reset)
    print(ui.colors.cyan .. "  Items:     " .. item_count .. " files" .. ui.colors.reset)
    print(ui.colors.cyan .. "  Comment:   " .. (comment or "No comment") .. ui.colors.reset)
    
    if zip_success then
        print(ui.colors.cyan .. "  Archive:   " .. zip_file .. ui.colors.reset)
    end
    
    ui.printSeparator(50, "─", ui.colors.green)
    
    return {
        success = true,
        path = zip_success and zip_file or backup_path,
        manifest = manifest,
        is_zipped = zip_success
    }
end

-- List available backups
function M.listBackups(location)
    local backups = {}
    
    -- Check for zip files
    local zip_files = utils.listFiles(location.path, "*.zip")
    for _, file in ipairs(zip_files) do
        local backup = M.getBackupInfo(file, true)
        if backup then
            table.insert(backups, backup)
        end
    end
    
    -- Check for directory backups
    local dirs = utils.captureCommand(string.format(
        "find '%s' -maxdepth 1 -type d -name 'divine_backup_*' 2>/dev/null",
        location.path
    ))
    
    if dirs then
        for dir in dirs:gmatch("[^\n]+") do
            local backup = M.getBackupInfo(dir, false)
            if backup then
                table.insert(backups, backup)
            end
        end
    end
    
    -- Sort by date (newest first)
    table.sort(backups, function(a, b)
        return a.timestamp > b.timestamp
    end)
    
    return backups
end

-- Get backup information
function M.getBackupInfo(path, is_zipped)
    local name = path:match("([^/]+)$")
    
    if is_zipped then
        -- Try to extract manifest from zip
        local temp_dir = "/data/local/tmp/backup_check_" .. os.time()
        utils.createDirectory(temp_dir)
        
        local extract_cmd = string.format(
            "unzip -p '%s' '*/manifest.json' 2>/dev/null",
            path
        )
        
        local manifest_json = utils.captureCommand(extract_cmd)
        utils.removeDirectory(temp_dir)
        
        if manifest_json then
            local success, manifest = pcall(cjson.decode, manifest_json)
            if success then
                manifest.path = path
                manifest.is_zipped = true
                return manifest
            end
        end
    else
        -- Directory backup
        local manifest_file = path .. "/manifest.json"
        local manifest_json = utils.readFile(manifest_file)
        
        if manifest_json then
            local success, manifest = pcall(cjson.decode, manifest_json)
            if success then
                manifest.path = path
                manifest.is_zipped = false
                return manifest
            end
        end
    end
    
    -- Fallback: extract info from filename
    local timestamp = name:match("divine_backup_.-_(%d+)_(%d+)")
    if timestamp then
        return {
            name = name,
            path = path,
            is_zipped = is_zipped,
            timestamp = os.time({year = tonumber(timestamp:sub(1,4)),
                                month = tonumber(timestamp:sub(5,6)),
                                day = tonumber(timestamp:sub(7,8)),
                                hour = tonumber(timestamp:sub(9,10)),
                                min = tonumber(timestamp:sub(11,12)),
                                sec = tonumber(timestamp:sub(13,14))}),
            date = string.format("%s-%s-%s %s:%s:%s",
                                timestamp:sub(1,4), timestamp:sub(5,6), timestamp:sub(7,8),
                                timestamp:sub(9,10), timestamp:sub(11,12), timestamp:sub(13,14))
        }
    end
    
    return nil
end

-- Restore backup
function M.restoreBackup(backup_info, options)
    print(ui.colors.cyan .. "\n🔧 RESTORING BACKUP: " .. backup_info.name .. ui.colors.reset)
    ui.printSeparator(50, "─", ui.colors.cyan)
    
    local temp_dir = "/data/local/tmp/backup_restore_" .. os.time()
    utils.createDirectory(temp_dir)
    
    -- Extract backup
    if backup_info.is_zipped then
        ui.showLoading("Extracting backup archive", 3)
        
        local success = utils.extractZip(backup_info.path, temp_dir)
        if not success then
            utils.removeDirectory(temp_dir)
            return {
                success = false,
                error = "Failed to extract backup archive"
            }
        end
    else
        -- Directory backup
        ui.showLoading("Preparing backup files", 1)
        utils.copy(backup_info.path, temp_dir)
    end
    
    -- Find backup root directory
    local backup_root = utils.captureCommand(string.format(
        "find '%s' -name 'manifest.json' -type f 2>/dev/null | head -1 | xargs dirname",
        temp_dir
    ))
    
    if not backup_root then
        utils.removeDirectory(temp_dir)
        return {
            success = false,
            error = "Backup structure corrupted"
        }
    end
    
    backup_root = backup_root:gsub("[\r\n]", "")
    
    -- Read manifest
    local manifest_file = backup_root .. "/manifest.json"
    local manifest_json = utils.readFile(manifest_file)
    
    if not manifest_json then
        utils.removeDirectory(temp_dir)
        return {
            success = false,
            error = "Backup manifest not found"
        }
    end
    
    local success, manifest = pcall(cjson.decode, manifest_json)
    if not success then
        utils.removeDirectory(temp_dir)
        return {
            success = false,
            error = "Invalid manifest format"
        }
    end
    
    -- Restore items based on options
    local restored_items = {}
    
    -- Restore config
    if options.restore_config then
        ui.showLoading("Restoring configuration", 1)
        
        local config_source = backup_root .. "/config"
        if utils.fileExists(config_source) then
            -- Backup current config first
            if options.backup_before_restore then
                local timestamp = os.date("%Y%m%d_%H%M%S")
                local backup_dest = BACKUP_LOCATIONS.INTERNAL.path .. "/pre_restore_" .. timestamp
                utils.copy("config", backup_dest)
            end
            
            -- Restore config
            utils.removeDirectory("config")
            utils.copy(config_source, "config")
            
            table.insert(restored_items, "config")
        end
    end
    
    -- Restore scripts
    if options.restore_scripts then
        ui.showLoading("Restoring scripts", 2)
        
        local scripts_source = backup_root .. "/scripts"
        if utils.fileExists(scripts_source) then
            -- Use script manager to restore scripts
            local script_manager = require("modules.script_manager")
            
            -- List all scripts in backup
            local cmd = string.format("find '%s' -type f -name '*.lua' -o -name '*.txt' 2>/dev/null", 
                                    scripts_source)
            local script_files = utils.captureCommand(cmd)
            
            if script_files then
                local count = 0
                for file in script_files:gmatch("[^\n]+") do
                    -- Extract executor and script name from path
                    local relative = file:gsub(scripts_source .. "/", "")
                    local executor, script_name = relative:match("([^/]+)/(.+)")
                    
                    if executor and script_name then
                        local content = utils.readFile(file)
                        if content then
                            -- Save to appropriate executor directory
                            script_manager.saveScript(executor, script_name, content, true)
                            count = count + 1
                        end
                    end
                end
                
                if count > 0 then
                    table.insert(restored_items, "scripts (" .. count .. " files)")
                end
            end
        end
    end
    
    -- Restore logs
    if options.restore_logs then
        ui.showLoading("Restoring logs", 1)
        
        local logs_source = backup_root .. "/logs"
        if utils.fileExists(logs_source) then
            utils.copy(logs_source, "logs")
            table.insert(restored_items, "logs")
        end
    end
    
    -- Restore data
    if options.restore_data then
        ui.showLoading("Restoring data", 1)
        
        local data_source = backup_root .. "/data"
        if utils.fileExists(data_source) then
            utils.copy(data_source, "data")
            table.insert(restored_items, "data")
        end
    end
    
    -- Cleanup
    utils.removeDirectory(temp_dir)
    
    -- Update backup state
    backup_state.last_restore = os.time()
    M.saveBackupState()
    
    -- Show summary
    print(ui.colors.green .. "\n✅ BACKUP RESTORED SUCCESSFULLY" .. ui.colors.reset)
    ui.printSeparator(50, "─", ui.colors.green)
    
    print(ui.colors.cyan .. "  Backup:    " .. manifest.name .. ui.colors.reset)
    print(ui.colors.cyan .. "  Date:      " .. manifest.date .. ui.colors.reset)
    print(ui.colors.cyan .. "  Type:      " .. manifest.type .. ui.colors.reset)
    print(ui.colors.cyan .. "  Version:   " .. (manifest.version or "Unknown") .. ui.colors.reset)
    
    if #restored_items > 0 then
        print(ui.colors.cyan .. "  Restored:  " .. table.concat(restored_items, ", ") .. ui.colors.reset)
    else
        print(ui.colors.yellow .. "  No items restored (check restore options)" .. ui.colors.reset)
    end
    
    ui.printSeparator(50, "─", ui.colors.green)
    
    return {
        success = true,
        manifest = manifest,
        restored_items = restored_items
    }
end

-- Delete backup
function M.deleteBackup(backup_info)
    if not ui.confirm(ui.colors.red .. "Are you sure you want to delete this backup?" .. ui.colors.reset, ui.colors.red) then
        return {success = false, error = "Cancelled"}
    end
    
    if backup_info.is_zipped then
        -- Delete zip file
        os.execute("rm -f " .. utils.escapeShellArg(backup_info.path))
    else
        -- Delete directory
        utils.removeDirectory(backup_info.path)
    end
    
    -- Update statistics
    if backup_info.total_size then
        backup_state.total_size = math.max(0, backup_state.total_size - backup_info.total_size)
    end
    
    backup_state.backup_count = math.max(0, backup_state.backup_count - 1)
    M.saveBackupState()
    
    return {success = true, name = backup_info.name}
end

-- Verify backup integrity
function M.verifyBackup(backup_info)
    print(ui.colors.cyan .. "[*] Verifying backup: " .. backup_info.name .. ui.colors.reset)
    
    local temp_dir = "/data/local/tmp/backup_verify_" .. os.time()
    utils.createDirectory(temp_dir)
    
    -- Extract if zipped
    if backup_info.is_zipped then
        local success = utils.extractZip(backup_info.path, temp_dir)
        if not success then
            utils.removeDirectory(temp_dir)
            return {success = false, error = "Failed to extract backup"}
        end
    else
        utils.copy(backup_info.path, temp_dir)
    end
    
    -- Check for manifest
    local manifest_file = temp_dir .. "/manifest.json"
    if not utils.fileExists(manifest_file) then
        -- Look for manifest in subdirectory
        local found = utils.captureCommand(string.format(
            "find '%s' -name 'manifest.json' -type f 2>/dev/null | head -1",
            temp_dir
        ))
        
        if found then
            manifest_file = found:gsub("[\r\n]", "")
        end
    end
    
    local results = {
        success = true,
        checks = {}
    }
    
    -- Check 1: Manifest exists
    if utils.fileExists(manifest_file) then
        table.insert(results.checks, {check = "Manifest exists", status = "✅"})
        
        -- Check 2: Manifest is valid JSON
        local content = utils.readFile(manifest_file)
        if content then
            local success, manifest = pcall(cjson.decode, content)
            if success then
                table.insert(results.checks, {check = "Manifest valid", status = "✅"})
                
                -- Check 3: Files mentioned in manifest exist
                for _, item in ipairs(manifest.items or {}) do
                    local check_dir = temp_dir .. "/" .. item.type
                    if utils.fileExists(check_dir) then
                        table.insert(results.checks, {
                            check = item.type .. " directory exists",
                            status = "✅"
                        })
                    else
                        table.insert(results.checks, {
                            check = item.type .. " directory exists",
                            status = "❌"
                        })
                        results.success = false
                    end
                end
            else
                table.insert(results.checks, {check = "Manifest valid", status = "❌"})
                results.success = false
            end
        else
            table.insert(results.checks, {check = "Manifest readable", status = "❌"})
            results.success = false
        end
    else
        table.insert(results.checks, {check = "Manifest exists", status = "❌"})
        results.success = false
    end
    
    -- Cleanup
    utils.removeDirectory(temp_dir)
    
    return results
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

-- Show backup menu
function M.showMenu()
    M.initialize()
    
    while true do
        ui.clearScreen()
        ui.printSeparator(54, "═", ui.colors.cyan)
        print("        " .. ui.colors.green .. "✦ BACKUP & RESTORE ✦" .. ui.colors.reset)
        ui.printSeparator(54, "═", ui.colors.cyan)
        
        -- Show statistics
        local stats = M.getStatistics()
        print(ui.colors.yellow .. "📊 Statistics:" .. ui.colors.reset)
        print(string.format("  Total Backups: %d", stats.total_backups))
        print(string.format("  Total Size:    %s", M.formatBytes(stats.total_size)))
        print(string.format("  Free Space:    %s", stats.free_space))
        
        if stats.last_backup then
            print(string.format("  Last Backup:   %s", os.date("%Y-%m-%d %H:%M", stats.last_backup)))
        end
        
        if stats.last_restore then
            print(string.format("  Last Restore:  %s", os.date("%Y-%m-%d %H:%M", stats.last_restore)))
        end
        
        ui.printSeparator(54, "─", ui.colors.yellow)
        
        print(ui.colors.cyan .. "  [1] Create New Backup" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Backup your configuration and scripts" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [2] Restore Backup" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Restore from previous backup" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [3] Manage Backups" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "View, verify, or delete backups" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [4] Backup Settings" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Configure backup options" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [5] Auto Backup" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Schedule automatic backups" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [6] Back to Main Menu" .. ui.colors.reset)
        
        ui.printSeparator(54, "═", ui.colors.cyan)
        
        local choice = ui.getNumberInput("\nSelect option (1-6): ", 1, 6)
        
        if choice == 1 then
            M.createBackupMenu()
        elseif choice == 2 then
            M.restoreBackupMenu()
        elseif choice == 3 then
            M.manageBackupsMenu()
        elseif choice == 4 then
            M.backupSettingsMenu()
        elseif choice == 5 then
            M.autoBackupMenu()
        elseif choice == 6 then
            break
        end
        
        ui.pressToContinue()
    end
end

-- Create backup menu
function M.createBackupMenu()
    ui.clearScreen()
    ui.printSeparator(54, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "✦ CREATE BACKUP ✦" .. ui.colors.reset)
    ui.printSeparator(54, "═", ui.colors.cyan)
    
    -- Select backup type
    print(ui.colors.yellow .. "Select backup type:" .. ui.colors.reset)
    for i, type_name in ipairs({"FULL", "CONFIG", "SCRIPTS", "SELECTIVE"}) do
        local backup_type = BACKUP_TYPES[type_name]
        print(string.format("  [%d] %s", i, backup_type.name))
        print("      " .. ui.colors.cyan .. backup_type.description .. ui.colors.reset)
    end
    
    local type_choice = ui.getNumberInput("\nSelect type (1-4): ", 1, 4)
    local type_keys = {"FULL", "CONFIG", "SCRIPTS", "SELECTIVE"}
    local backup_type = BACKUP_TYPES[type_keys[type_choice]]
    
    -- For selective backup, choose items
    local items = {}
    if backup_type.name == "Selective Backup" then
        print(ui.colors.yellow .. "\nSelect items to backup:" .. ui.colors.reset)
        print("  [1] Configuration files")
        print("  [2] Script files")
        print("  [3] Log files")
        print("  [4] Data files")
        print("  [5] All of the above")
        
        local item_choice = ui.getNumberInput("\nSelect items (e.g., 1,2,3 or 5): ", 1, 5)
        
        if item_choice == 5 then
            items = {"config", "scripts", "logs", "data"}
        else
            -- Parse multiple selections
            for str in tostring(item_choice):gmatch("[^,]+") do
                local idx = tonumber(str)
                if idx == 1 then table.insert(items, "config") end
                if idx == 2 then table.insert(items, "scripts") end
                if idx == 3 then table.insert(items, "logs") end
                if idx == 4 then table.insert(items, "data") end
            end
        end
        
        if #items == 0 then
            ui.showMessage("No items selected for backup", "warning")
            return
        end
    else
        items = backup_type.includes
    end
    
    -- Select location
    print(ui.colors.yellow .. "\nSelect backup location:" .. ui.colors.reset)
    local available_locations = {}
    
    for i, loc_key in ipairs({"INTERNAL", "EXTERNAL", "CUSTOM"}) do
        local location = BACKUP_LOCATIONS[loc_key]
        if loc_key == "EXTERNAL" and not location.accessible then
            print(string.format("  [%d] %s %s", i, location.name, ui.colors.red .. "(Not accessible)" .. ui.colors.reset))
        else
            print(string.format("  [%d] %s", i, location.name))
            print("      " .. ui.colors.cyan .. location.path .. ui.colors.reset)
            table.insert(available_locations, location)
        end
    end
    
    local loc_choice = ui.getNumberInput("\nSelect location (1-" .. #available_locations .. "): ", 1, #available_locations)
    local location = available_locations[loc_choice]
    
    -- Custom location
    if location.name == "Custom Location" then
        io.write(ui.colors.yellow .. "Enter custom path: " .. ui.colors.reset)
        location.path = io.read():gsub("%s+", "")
        
        if location.path == "" then
            ui.showMessage("Custom path cannot be empty", "error")
            return
        end
        
        -- Create directory if it doesn't exist
        utils.createDirectory(location.path)
    end
    
    -- Add comment
    io.write(ui.colors.yellow .. "\nBackup comment (optional): " .. ui.colors.reset)
    local comment = io.read()
    
    -- Create backup
    M.createBackup(backup_type, location, items, comment)
end

-- Restore backup menu
function M.restoreBackupMenu()
    ui.clearScreen()
    ui.printSeparator(54, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "✦ RESTORE BACKUP ✦" .. ui.colors.reset)
    ui.printSeparator(54, "═", ui.colors.cyan)
    
    -- Select location
    print(ui.colors.yellow .. "Select backup location:" .. ui.colors.reset)
    local available_locations = {}
    
    for i, loc_key in ipairs({"INTERNAL", "EXTERNAL"}) do
        local location = BACKUP_LOCATIONS[loc_key]
        if location.accessible then
            print(string.format("  [%d] %s", i, location.name))
            print("      " .. ui.colors.cyan .. location.path .. ui.colors.reset)
            table.insert(available_locations, location)
        end
    end
    
    if #available_locations == 0 then
        ui.showMessage("No backup locations available", "error")
        return
    end
    
    local loc_choice = ui.getNumberInput("\nSelect location (1-" .. #available_locations .. "): ", 1, #available_locations)
    local location = available_locations[loc_choice]
    
    -- List backups
    local backups = M.listBackups(location)
    
    if #backups == 0 then
        ui.showMessage("No backups found in " .. location.name, "warning")
        return
    end
    
    -- Display backups
    ui.clearScreen()
    ui.printSeparator(70, "═", ui.colors.green)
    print("        " .. ui.colors.cyan .. "AVAILABLE BACKUPS" .. ui.colors.reset)
    ui.printSeparator(70, "═", ui.colors.green)
    
    local headers = {"#", "Name", "Date", "Type", "Size", "Status"}
    local rows = {}
    
    for i, backup in ipairs(backups) do
        local status = backup.is_zipped and "ZIP" or "DIR"
        local size = backup.total_size and M.formatBytes(backup.total_size) or "Unknown"
        
        table.insert(rows, {
            i,
            backup.name:sub(1, 20),
            backup.date or "Unknown",
            backup.type or "Unknown",
            size,
            status
        })
    end
    
    ui.displayTable(headers, rows, "Total: " .. #backups .. " backups")
    
    -- Select backup
    local backup_choice = ui.getNumberInput("\nSelect backup to restore (1-" .. #backups .. "): ", 1, #backups)
    local backup = backups[backup_choice]
    
    -- Verify backup first
    print(ui.colors.yellow .. "\nVerifying backup integrity..." .. ui.colors.reset)
    local verification = M.verifyBackup(backup)
    
    if not verification.success then
        ui.showMessage("Backup verification failed!", "error")
        print(ui.colors.red .. "Errors:" .. ui.colors.reset)
        for _, check in ipairs(verification.checks) do
            print("  " .. check.check .. ": " .. check.status)
        end
        
        if not ui.confirm("Restore anyway?", ui.colors.red) then
            return
        end
    end
    
    -- Select restore options
    print(ui.colors.yellow .. "\nSelect items to restore:" .. ui.colors.reset)
    local options = {
        backup_before_restore = ui.confirm("Backup current files before restore?", ui.colors.yellow),
        restore_config = ui.confirm("Restore configuration?", ui.colors.yellow),
        restore_scripts = ui.confirm("Restore scripts?", ui.colors.yellow),
        restore_logs = ui.confirm("Restore logs?", ui.colors.yellow),
        restore_data = ui.confirm("Restore data?", ui.colors.yellow)
    }
    
    -- Confirm restore
    if not ui.confirm(ui.colors.red .. "Are you sure you want to restore this backup?" .. ui.colors.reset, ui.colors.red) then
        return
    end
    
    -- Perform restore
    M.restoreBackup(backup, options)
end

-- Manage backups menu
function M.manageBackupsMenu()
    ui.clearScreen()
    ui.printSeparator(54, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "✦ MANAGE BACKUPS ✦" .. ui.colors.reset)
    ui.printSeparator(54, "═", ui.colors.cyan)
    
    -- Select location
    local location = BACKUP_LOCATIONS.INTERNAL
    
    -- List backups
    local backups = M.listBackups(location)
    
    if #backups == 0 then
        ui.showMessage("No backups found", "info")
        return
    end
    
    -- Display backups with more details
    for i, backup in ipairs(backups) do
        print(string.format("\n[%d] %s", i, backup.name))
        print(ui.colors.cyan .. "    Date:    " .. (backup.date or "Unknown") .. ui.colors.reset)
        print(ui.colors.cyan .. "    Type:    " .. (backup.type or "Unknown") .. ui.colors.reset)
        print(ui.colors.cyan .. "    Size:    " .. (backup.total_size and M.formatBytes(backup.total_size) or "Unknown") .. ui.colors.reset)
        print(ui.colors.cyan .. "    Format:  " .. (backup.is_zipped and "ZIP" or "Directory") .. ui.colors.reset)
        
        if backup.comment and backup.comment ~= "" then
            print(ui.colors.cyan .. "    Comment: " .. backup.comment .. ui.colors.reset)
        end
    end
    
    print()
    print(ui.colors.yellow .. "Actions:" .. ui.colors.reset)
    print("  [v#] Verify backup (e.g., v1)")
    print("  [d#] Delete backup (e.g., d1)")
    print("  [i#] Show backup info (e.g., i1)")
    print("  [q] Back")
    
    io.write(ui.colors.yellow .. "\nSelect action: " .. ui.colors.reset)
    local input = io.read():lower()
    
    if input == "q" then
        return
    end
    
    local action, num = input:match("([vdi])(%d+)")
    if action and num then
        local idx = tonumber(num)
        if idx >= 1 and idx <= #backups then
            local backup = backups[idx]
            
            if action == "v" then
                -- Verify
                local results = M.verifyBackup(backup)
                
                print(ui.colors.cyan .. "\n🔍 VERIFICATION RESULTS" .. ui.colors.reset)
                ui.printSeparator(50, "─", ui.colors.cyan)
                
                for _, check in ipairs(results.checks) do
                    local status_color = check.status == "✅" and ui.colors.green or ui.colors.red
                    print(string.format("  %-30s: %s", check.check, status_color .. check.status .. ui.colors.reset))
                end
                
                ui.printSeparator(50, "─", ui.colors.cyan)
                print(ui.colors.yellow .. "  Overall: " .. (results.success and "✅ PASS" or "❌ FAIL") .. ui.colors.reset)
                
            elseif action == "d" then
                -- Delete
                local result = M.deleteBackup(backup)
                if result.success then
                    ui.showMessage("Backup deleted: " .. result.name, "success")
                else
                    ui.showMessage("Delete failed: " .. result.error, "error")
                end
                
            elseif action == "i" then
                -- Info
                print(ui.colors.cyan .. "\n📄 BACKUP INFORMATION" .. ui.colors.reset)
                ui.printSeparator(50, "─", ui.colors.cyan)
                
                for key, value in pairs(backup) do
                    if type(value) == "table" then
                        print(string.format("  %-15s:", key))
                        for k, v in pairs(value) do
                            print(string.format("    %-12s: %s", k, tostring(v)))
                        end
                    else
                        print(string.format("  %-15s: %s", key, tostring(value)))
                    end
                end
                
                ui.printSeparator(50, "─", ui.colors.cyan)
            end
        end
    end
end

-- Backup settings menu
function M.backupSettingsMenu()
    ui.clearScreen()
    ui.printSeparator(54, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "✦ BACKUP SETTINGS ✦" .. ui.colors.reset)
    ui.printSeparator(54, "═", ui.colors.cyan)
    
    -- Load settings from config
    local config_data = config.load()
    local backup_settings = config_data.backup_settings or {
        auto_backup = false,
        backup_interval = 24, -- hours
        max_backups = 10,
        compress_backups = true,
        backup_on_exit = false
    }
    
    print(ui.colors.yellow .. "Current Settings:" .. ui.colors.reset)
    print(string.format("  Auto Backup:      %s", backup_settings.auto_backup and "Enabled" or "Disabled"))
    print(string.format("  Backup Interval:  %d hours", backup_settings.backup_interval))
    print(string.format("  Max Backups:      %d", backup_settings.max_backups))
    print(string.format("  Compress:         %s", backup_settings.compress_backups and "Yes" : "No"))
    print(string.format("  Backup on Exit:   %s", backup_settings.backup_on_exit and "Yes" : "No"))
    
    ui.printSeparator(54, "─", ui.colors.yellow)
    
    print(ui.colors.cyan .. "  [1] Toggle Auto Backup" .. ui.colors.reset)
    print(ui.colors.cyan .. "  [2] Set Backup Interval" .. ui.colors.reset)
    print(ui.colors.cyan .. "  [3] Set Max Backups" .. ui.colors.reset)
    print(ui.colors.cyan .. "  [4] Toggle Compression" .. ui.colors.reset)
    print(ui.colors.cyan .. "  [5] Toggle Backup on Exit" .. ui.colors.reset)
    print(ui.colors.cyan .. "  [6] Save Settings" .. ui.colors.reset)
    print(ui.colors.cyan .. "  [7] Back" .. ui.colors.reset)
    
    local choice = ui.getNumberInput("\nSelect option (1-7): ", 1, 7)
    
    if choice == 1 then
        backup_settings.auto_backup = not backup_settings.auto_backup
        print(ui.colors.green .. "Auto Backup: " .. (backup_settings.auto_backup and "Enabled" : "Disabled") .. ui.colors.reset)
        
    elseif choice == 2 then
        local interval = ui.getNumberInput("Backup interval (hours, 1-168): ", 1, 168)
        backup_settings.backup_interval = interval
        print(ui.colors.green .. "Backup interval set to " .. interval .. " hours" .. ui.colors.reset)
        
    elseif choice == 3 then
        local max_backups = ui.getNumberInput("Maximum backups to keep (1-100): ", 1, 100)
        backup_settings.max_backups = max_backups
        print(ui.colors.green .. "Maximum backups set to " .. max_backups .. ui.colors.reset)
        
    elseif choice == 4 then
        backup_settings.compress_backups = not backup_settings.compress_backups
        print(ui.colors.green .. "Compression: " .. (backup_settings.compress_backups and "Enabled" : "Disabled") .. ui.colors.reset)
        
    elseif choice == 5 then
        backup_settings.backup_on_exit = not backup_settings.backup_on_exit
        print(ui.colors.green .. "Backup on Exit: " .. (backup_settings.backup_on_exit and "Enabled" : "Disabled") .. ui.colors.reset)
        
    elseif choice == 6 then
        config_data.backup_settings = backup_settings
        config.save(config_data)
        ui.showMessage("Backup settings saved", "success")
    end
end

-- Auto backup menu
function M.autoBackupMenu()
    ui.clearScreen()
    ui.printSeparator(54, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "✦ AUTO BACKUP ✦" .. ui.colors.reset)
    ui.printSeparator(54, "═", ui.colors.cyan)
    
    local config_data = config.load()
    local backup_settings = config_data.backup_settings or {}
    
    if not backup_settings.auto_backup then
        print(ui.colors.red .. "Auto backup is disabled!" .. ui.colors.reset)
        print(ui.colors.yellow .. "Enable it in Backup Settings first." .. ui.colors.reset)
        return
    end
    
    print(ui.colors.yellow .. "Auto Backup Status: " .. ui.colors.green .. "ACTIVE" .. ui.colors.reset)
    print(ui.colors.yellow .. "Next backup in: " .. ui.colors.cyan .. "Calculating..." .. ui.colors.reset)
    print(ui.colors.yellow .. "Backup location: " .. ui.colors.cyan .. BACKUP_LOCATIONS.INTERNAL.path .. ui.colors.reset)
    
    ui.printSeparator(54, "─", ui.colors.yellow)
    
    print(ui.colors.cyan .. "  [1] Run Backup Now" .. ui.colors.reset)
    print(ui.colors.cyan .. "  [2] View Backup Log" .. ui.colors.reset)
    print(ui.colors.cyan .. "  [3] Clean Old Backups" .. ui.colors.reset)
    print(ui.colors.cyan .. "  [4] Back" .. ui.colors.reset)
    
    local choice = ui.getNumberInput("\nSelect option (1-4): ", 1, 4)
    
    if choice == 1 then
        -- Run backup now
        local result = M.createBackup(
            BACKUP_TYPES.FULL,
            BACKUP_LOCATIONS.INTERNAL,
            BACKUP_TYPES.FULL.includes,
            "Manual auto-backup"
        )
        
        if result.success then
            ui.showMessage("Auto backup completed", "success")
        end
        
    elseif choice == 2 then
        -- View backup log
        local log_file = BACKUP_LOCATIONS.INTERNAL.path .. "/backup.log"
        if utils.fileExists(log_file) then
            local content = utils.readFile(log_file)
            print(ui.colors.cyan .. "\n📄 BACKUP LOG" .. ui.colors.reset)
            ui.printSeparator(80, "─", ui.colors.cyan)
            print(content)
            ui.printSeparator(80, "─", ui.colors.cyan)
        else
            ui.showMessage("No backup log found", "info")
        end
        
    elseif choice == 3 then
        -- Clean old backups
        M.cleanOldBackups()
    end
end

-- Clean old backups
function M.cleanOldBackups()
    local config_data = config.load()
    local backup_settings = config_data.backup_settings or {}
    local max_backups = backup_settings.max_backups or 10
    
    local backups = M.listBackups(BACKUP_LOCATIONS.INTERNAL)
    
    if #backups <= max_backups then
        ui.showMessage("No backups to clean (" .. #backups .. "/" .. max_backups .. ")", "info")
        return
    end
    
    print(ui.colors.yellow .. "Cleaning old backups..." .. ui.colors.reset)
    print(ui.colors.cyan .. "Keeping " .. max_backups .. " newest backups" .. ui.colors.reset)
    
    local to_delete = #backups - max_backups
    local deleted = 0
    
    for i = max_backups + 1, #backups do
        local backup = backups[i]
        print(ui.colors.yellow .. "  Deleting: " .. backup.name .. ui.colors.reset)
        
        local result = M.deleteBackup(backup)
        if result.success then
            deleted = deleted + 1
        end
    end
    
    ui.showMessage("Cleaned " .. deleted .. " old backups", "success")
end

-- Perform auto backup (called from main loop)
function M.performAutoBackup()
    local config_data = config.load()
    local backup_settings = config_data.backup_settings or {}
    
    if not backup_settings.auto_backup then
        return false
    end
    
    -- Check if it's time for backup
    local last_backup = backup_state.last_backup or 0
    local interval = (backup_settings.backup_interval or 24) * 3600  -- Convert to seconds
    local now = os.time()
    
    if now - last_backup >= interval then
        print(ui.colors.cyan .. "[*] Performing scheduled auto backup..." .. ui.colors.reset)
        
        local result = M.createBackup(
            BACKUP_TYPES.FULL,
            BACKUP_LOCATIONS.INTERNAL,
            BACKUP_TYPES.FULL.includes,
            "Scheduled auto-backup"
        )
        
        -- Clean old backups if needed
        M.cleanOldBackups()
        
        return result.success
    end
    
    return false
end

-- Backup on exit
function M.backupOnExit()
    local config_data = config.load()
    local backup_settings = config_data.backup_settings or {}
    
    if backup_settings.backup_on_exit then
        print(ui.colors.cyan .. "[*] Creating backup before exit..." .. ui.colors.reset)
        
        local result = M.createBackup(
            BACKUP_TYPES.CONFIG,
            BACKUP_LOCATIONS.INTERNAL,
            BACKUP_TYPES.CONFIG.includes,
            "Exit backup"
        )
        
        return result.success
    end
    
    return false
end

return M