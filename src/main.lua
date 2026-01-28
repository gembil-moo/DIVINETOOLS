-- DIVINETOOLS v2.0 - Main Entry Point
-- Modular Architecture - Integrated All Modules

-- Load modules with error handling
local function safeRequire(module_name)
    local success, module = pcall(require, module_name)
    if not success then
        print("\27[31m[ERROR] Failed to load module: " .. module_name .. "\27[0m")
        print("\27[33mPlease run: bash install.sh\27[0m")
        return nil
    end
    return module
end

-- Try to load modules
local config = safeRequire("modules.config")
local ui = safeRequire("modules.ui")
local utils = safeRequire("modules.utils")
local monitor = safeRequire("modules.monitor")
local optimizer = safeRequire("modules.optimizer")
local webhook = safeRequire("modules.webhook")
local script_manager = safeRequire("modules.script_manager")
local backup = safeRequire("modules.backup")
local uninstall = safeRequire("modules.uninstall")

-- Check if all modules loaded
if not (config and ui and utils and monitor and optimizer and 
        script_manager and backup and uninstall) then
    print("\27[31m[FATAL] Essential modules missing. Installation may be incomplete.\27[0m")
    print("\27[33mPlease run: bash install.sh\27[0m")
    os.exit(1)
end

-- Version
local VERSION = "2.0.0"
local BUILD_DATE = "2024-01-15"

-- Global state
local app_state = {
    running = true,
    current_menu = "main",
    last_error = nil,
    startup_time = os.time()
}

-- Signal handler for graceful shutdown
local function setupSignalHandlers()
    -- Handle CTRL+C
    local function gracefulShutdown()
        if app_state.running then
            print("\n\n" .. ui.colors.yellow .. "[!] Received interrupt signal. Stopping gracefully..." .. ui.colors.reset)
            
            -- Backup on exit if configured
            local config_data = config.load()
            if config_data.backup_settings and config_data.backup_settings.backup_on_exit then
                backup.backupOnExit()
            end
            
            app_state.running = false
            utils.sleep(1)
            print(ui.colors.green .. "[+] DIVINETOOLS shutdown complete. Goodbye! 👋" .. ui.colors.reset)
            os.exit(0)
        end
    end
    
    -- Try to use posix signals if available
    local ok, posix = pcall(require, "posix.signal")
    if ok then
        posix.signal(posix.SIGINT, gracefulShutdown)
        posix.signal(posix.SIGTERM, gracefulShutdown)
    else
        -- Fallback: manual signal handling
        print(ui.colors.yellow .. "[!] Limited signal handling. Use menu to exit properly." .. ui.colors.reset)
    end
end

-- Check environment and dependencies
local function checkEnvironment()
    local issues = {}
    local warnings = {}
    
    print(ui.colors.cyan .. "[*] Checking environment..." .. ui.colors.reset)
    
    -- Check Lua version
    local lua_version = _VERSION:match("%d+%.%d+")
    if tonumber(lua_version) < 5.3 then
        table.insert(issues, "Lua 5.3+ required (found " .. lua_version .. ")")
    end
    
    -- Check required Lua modules
    local required_lua_modules = {"cjson", "socket"}
    for _, mod in ipairs(required_lua_modules) do
        local ok, _ = pcall(require, mod)
        if not ok then
            table.insert(issues, "Missing Lua module: " .. mod)
        end
    end
    
    -- Check root access
    if not utils.isRootAvailable() then
        table.insert(warnings, "Root access not available. Some features will be limited.")
    end
    
    -- Check Termux environment
    if not os.getenv("TERMUX_VERSION") then
        table.insert(warnings, "Not running in Termux. Some features may not work correctly.")
    end
    
    -- Check disk space
    local free_space = utils.getStorageInfo()
    if free_space and free_space.available then
        local available_mb = tonumber(free_space.available:match("%d+%.?%d*")) or 0
        if available_mb < 100 then  -- Less than 100MB free
            table.insert(warnings, "Low disk space: " .. free_space.available)
        end
    end
    
    -- Check internet connectivity (optional)
    if not utils.checkInternet() then
        table.insert(warnings, "No internet connection. Webhook features will be disabled.")
    end
    
    -- Display results
    if #issues > 0 then
        print(ui.colors.red .. "[!] Found " .. #issues .. " critical issue(s):" .. ui.colors.reset)
        for _, issue in ipairs(issues) do
            print("  - " .. issue)
        end
    end
    
    if #warnings > 0 then
        print(ui.colors.yellow .. "[!] Found " .. #warnings .. " warning(s):" .. ui.colors.reset)
        for _, warning in ipairs(warnings) do
            print("  - " .. warning)
        end
    end
    
    if #issues == 0 and #warnings == 0 then
        print(ui.colors.green .. "[+] Environment check passed" .. ui.colors.reset)
    end
    
    return #issues == 0, issues, warnings
end

-- Initialize all modules
local function initializeModules()
    print(ui.colors.cyan .. "[*] Initializing modules..." .. ui.colors.reset)
    
    local results = {
        config = config.load(),
        ui = true,  -- UI module doesn't need explicit init
        utils = utils.setupSignalHandler(),
        monitor = true,  -- Will be initialized when needed
        optimizer = true,  -- Will be initialized when needed
        webhook = webhook.initialize(),
        script_manager = script_manager.initialize(),
        backup = backup.initialize(),
        uninstall = true   -- Will be initialized when needed
    }
    
    -- Check initialization results
    local failed = {}
    for module_name, result in pairs(results) do
        if not result then
            table.insert(failed, module_name)
        end
    end
    
    if #failed > 0 then
        print(ui.colors.red .. "[!] Failed to initialize modules: " .. table.concat(failed, ", ") .. ui.colors.reset)
        return false
    end
    
    print(ui.colors.green .. "[+] All modules initialized successfully" .. ui.colors.reset)
    return true
end

-- Show main menu
local function showMainMenu()
    ui.clearScreen()
    ui.printBanner(VERSION)
    
    print(ui.colors.cyan .. "        ✦ BUILD " .. BUILD_DATE .. " ✦" .. ui.colors.reset)
    ui.printSeparator(54, "═", ui.colors.cyan)
    
    -- Show quick stats if config exists
    local config_data = config.load()
    if #config_data.packages > 0 then
        print(ui.colors.yellow .. "📊 Quick Stats:" .. ui.colors.reset)
        print(ui.colors.cyan .. "  Packages: " .. #config_data.packages .. 
              " | Webhook: " .. (config_data.webhook.enabled and "✅" or "❌") ..
              " | Auto Backup: " .. (config_data.backup_settings and config_data.backup_settings.auto_backup and "✅" or "❌") .. ui.colors.reset)
        ui.printSeparator(54, "─", ui.colors.cyan)
    end
    
    print(ui.colors.red .. "║" .. ui.colors.reset .. "  [1] 🚀 Start Monitoring")
    print(ui.colors.red .. "║" .. ui.colors.reset .. "  [2] ⚙️  First Configuration")
    print(ui.colors.red .. "║" .. ui.colors.reset .. "  [3] 📝 Edit Configuration")
    print(ui.colors.red .. "║" .. ui.colors.reset .. "  [4] 🔧 Optimize Device")
    print(ui.colors.red .. "║" .. ui.colors.reset .. "  [5] 📜 Script Manager")
    print(ui.colors.red .. "║" .. ui.colors.reset .. "  [6] 💾 Backup & Restore")
    print(ui.colors.red .. "║" .. ui.colors.reset .. "  [7] 🛠️  Tools & Utilities")
    print(ui.colors.red .. "║" .. ui.colors.reset .. "  [8] 🗑️  Uninstall")
    print(ui.colors.red .. "║" .. ui.colors.reset .. "  [9] ℹ️  System Info")
    print(ui.colors.red .. "║" .. ui.colors.reset .. "  [0] 🚪 Exit")
    
    ui.printSeparator(54, "═", ui.colors.red)
end

-- Show system information
local function showSystemInfo()
    ui.clearScreen()
    ui.printSeparator(60, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "✦ SYSTEM INFORMATION ✦" .. ui.colors.reset)
    ui.printSeparator(60, "═", ui.colors.cyan)
    
    print(ui.colors.yellow .. "📱 Device Information:" .. ui.colors.reset)
    print("  Model:       " .. (utils.getDeviceModel() or "Unknown"))
    print("  Android:     " .. (utils.getAndroidVersion() or "Unknown"))
    
    print(ui.colors.yellow .. "\n💾 Storage Information:" .. ui.colors.reset)
    local storage = utils.getStorageInfo()
    if storage then
        print("  Total:       " .. storage.total)
        print("  Used:        " .. storage.used)
        print("  Available:   " .. storage.available)
    else
        print("  Unable to read storage information")
    end
    
    print(ui.colors.yellow .. "\n🧠 Memory Information:" .. ui.colors.reset)
    local memory = utils.getMemoryUsage()
    if memory then
        print("  Total:       " .. string.format("%.1f MB", memory.total / 1024))
        print("  Used:        " .. string.format("%.1f MB", memory.used / 1024))
        print("  Available:   " .. string.format("%.1f MB", memory.available / 1024))
        print("  Usage:       " .. string.format("%.1f%%", memory.percent))
    else
        print("  Unable to read memory information")
    end
    
    print(ui.colors.yellow .. "\n🔋 Battery Status:" .. ui.colors.reset)
    local battery = utils.getBatteryStatus()
    if battery then
        print("  Capacity:    " .. battery.capacity .. "%")
        print("  Status:      " .. battery.status)
    else
        print("  Unable to read battery information")
    end
    
    print(ui.colors.yellow .. "\n📦 DIVINETOOLS Information:" .. ui.colors.reset)
    print("  Version:     " .. VERSION)
    print("  Build Date:  " .. BUILD_DATE)
    print("  Uptime:      " .. utils.formatTime(os.time() - app_state.startup_time))
    
    local config_data = config.load()
    print("  Packages:    " .. #config_data.packages)
    print("  Webhook:     " .. (config_data.webhook.enabled and "Enabled" or "Disabled"))
    
    ui.printSeparator(60, "═", ui.colors.cyan)
    
    -- Quick diagnostics
    print(ui.colors.yellow .. "\n🔍 Quick Diagnostics:" .. ui.colors.reset)
    print("  Root Access: " .. (utils.isRootAvailable() and "✅" or "❌"))
    print("  Internet:    " .. (utils.checkInternet() and "✅" or "❌"))
    
    local executors = script_manager.getAvailableExecutors()
    print("  Executors:   " .. #executors .. " found")
    
    ui.printSeparator(60, "═", ui.colors.cyan)
end

-- Show tools and utilities menu
local function showToolsMenu()
    while true do
        ui.clearScreen()
        ui.printSeparator(54, "═", ui.colors.cyan)
        print("        " .. ui.colors.green .. "✦ TOOLS & UTILITIES ✦" .. ui.colors.reset)
        ui.printSeparator(54, "═", ui.colors.cyan)
        
        print(ui.colors.cyan .. "  [1] 📡 Webhook Test" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Test Discord webhook connection" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [2] 🔍 Package Scanner" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Scan for Roblox packages" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [3] 🧹 Cache Cleaner" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Clear system and package cache" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [4] 📊 Performance Test" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Run system performance benchmark" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [5] 🔄 Auto-Script Injection" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Inject Divine Monitor scripts" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [6] 📝 Log Viewer" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "View application logs" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [7] ⚙️  Advanced Settings" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Advanced configuration options" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [8] ↩️  Back to Main Menu" .. ui.colors.reset)
        
        ui.printSeparator(54, "═", ui.colors.cyan)
        
        local choice = ui.getNumberInput("\nSelect option (1-8): ", 1, 8)
        
        if choice == 1 then
            -- Webhook test
            local config_data = config.load()
            if config_data.webhook.enabled then
                webhook.testConfiguration(config_data)
            else
                ui.showMessage("Webhook is not enabled in configuration", "warning")
            end
            
        elseif choice == 2 then
            -- Package scanner
            ui.clearScreen()
            ui.printSeparator(50, "═", ui.colors.cyan)
            print("        " .. ui.colors.green .. "✦ PACKAGE SCANNER ✦" .. ui.colors.reset)
            ui.printSeparator(50, "═", ui.colors.cyan)
            
            print(ui.colors.yellow .. "[*] Scanning for Roblox packages..." .. ui.colors.reset)
            local packages = config.scanPackages()
            
            if #packages == 0 then
                print(ui.colors.red .. "[!] No Roblox packages found" .. ui.colors.reset)
            else
                print(ui.colors.green .. "[+] Found " .. #packages .. " package(s):" .. ui.colors.reset)
                for i, pkg in ipairs(packages) do
                    local user = config.getUsername(pkg)
                    local status = user and (ui.colors.green .. "✓ Logged in" .. ui.colors.reset) or 
                                            (ui.colors.yellow .. "✗ Not logged in" .. ui.colors.reset)
                    print(string.format("  [%d] %-30s %s", i, pkg, status))
                end
            end
            
        elseif choice == 3 then
            -- Cache cleaner
            ui.clearScreen()
            ui.printSeparator(50, "═", ui.colors.cyan)
            print("        " .. ui.colors.green .. "✦ CACHE CLEANER ✦" .. ui.colors.reset)
            ui.printSeparator(50, "═", ui.colors.cyan)
            
            if ui.confirm("Clear system cache? This may improve performance.", ui.colors.yellow) then
                optimizer.clearSystemCache()
            end
            
            local config_data = config.load()
            if #config_data.packages > 0 and ui.confirm("Clear package caches?", ui.colors.yellow) then
                for _, pkg in ipairs(config_data.packages) do
                    os.execute("su -c 'pm clear " .. pkg .. "' 2>/dev/null")
                    print(ui.colors.green .. "  ✓ Cleared: " .. pkg .. ui.colors.reset)
                end
            end
            
            ui.showMessage("Cache cleaning completed", "success")
            
        elseif choice == 4 then
            -- Performance test
            optimizer.runBenchmark()
            
        elseif choice == 5 then
            -- Auto-script injection
            local config_data = config.load()
            if config_data.webhook.enabled then
                print(ui.colors.yellow .. "[*] Injecting Divine Monitor scripts..." .. ui.colors.reset)
                local results = script_manager.autoInjectDivineMonitor(config_data)
                
                local success_count = 0
                for _, result in ipairs(results) do
                    if result.success then
                        success_count = success_count + 1
                    end
                end
                
                ui.showMessage("Injected scripts to " .. success_count .. "/" .. #results .. " packages", 
                              success_count == #results and "success" or "warning")
            else
                ui.showMessage("Webhook must be enabled for script injection", "error")
            end
            
        elseif choice == 6 then
            -- Log viewer
            ui.clearScreen()
            ui.printSeparator(70, "═", ui.colors.cyan)
            print("        " .. ui.colors.green .. "✦ LOG VIEWER ✦" .. ui.colors.reset)
            ui.printSeparator(70, "═", ui.colors.cyan)
            
            local log_files = utils.listFiles("logs", "*.log")
            if #log_files == 0 then
                print(ui.colors.yellow .. "No log files found" .. ui.colors.reset)
            else
                print(ui.colors.yellow .. "Available log files:" .. ui.colors.reset)
                for i, file in ipairs(log_files) do
                    local size = utils.getFileSize(file)
                    local name = file:match("([^/]+)$")
                    print(string.format("  [%d] %-30s (%s)", i, name, utils.formatBytes(size)))
                end
                
                local file_choice = ui.getNumberInput("\nSelect log file to view (1-" .. #log_files .. "): ", 1, #log_files)
                local selected_file = log_files[file_choice]
                
                local content = utils.readFile(selected_file)
                if content then
                    ui.clearScreen()
                    ui.printSeparator(80, "═", ui.colors.cyan)
                    print("        " .. ui.colors.green .. "LOG: " .. selected_file .. ui.colors.reset)
                    ui.printSeparator(80, "═", ui.colors.cyan)
                    
                    -- Show last 100 lines
                    local lines = {}
                    for line in content:gmatch("[^\n]+") do
                        table.insert(lines, line)
                    end
                    
                    local start = math.max(1, #lines - 100)
                    for i = start, #lines do
                        print(lines[i])
                    end
                    
                    ui.printSeparator(80, "═", ui.colors.cyan)
                end
            end
            
        elseif choice == 7 then
            -- Advanced settings
            ui.clearScreen()
            ui.printSeparator(54, "═", ui.colors.cyan)
            print("        " .. ui.colors.green .. "✦ ADVANCED SETTINGS ✦" .. ui.colors.reset)
            ui.printSeparator(54, "═", ui.colors.cyan)
            
            print(ui.colors.cyan .. "  [1] Reset All Settings" .. ui.colors.reset)
            print("      " .. ui.colors.yellow .. "Reset to factory defaults" .. ui.colors.reset)
            
            print(ui.colors.cyan .. "\n  [2] Export Configuration" .. ui.colors.reset)
            print("      " .. ui.colors.yellow .. "Export current configuration" .. ui.colors.reset)
            
            print(ui.colors.cyan .. "\n  [3] Import Configuration" .. ui.colors.reset)
            print("      " .. ui.colors.yellow .. "Import configuration from file" .. ui.colors.reset)
            
            print(ui.colors.cyan .. "\n  [4] Update Check" .. ui.colors.reset)
            print("      " .. ui.colors.yellow .. "Check for updates" .. ui.colors.reset)
            
            print(ui.colors.cyan .. "\n  [5] Debug Mode" .. ui.colors.reset)
            print("      " .. ui.colors.yellow .. "Enable debug logging" .. ui.colors.reset)
            
            print(ui.colors.cyan .. "\n  [6] Back" .. ui.colors.reset)
            
            local adv_choice = ui.getNumberInput("\nSelect option (1-6): ", 1, 6)
            
            if adv_choice == 1 then
                if ui.confirm(ui.colors.red .. "Reset ALL settings to factory defaults?" .. ui.colors.reset, ui.colors.red) then
                    os.execute("rm -rf config/* 2>/dev/null")
                    ui.showMessage("All settings have been reset", "success")
                end
            elseif adv_choice == 2 then
                local config_data = config.load()
                local json_data = cjson.encode(config_data)
                local timestamp = os.date("%Y%m%d_%H%M%S")
                local filename = "divine_config_" .. timestamp .. ".json"
                
                if utils.writeFile(filename, json_data) then
                    ui.showMessage("Configuration exported to: " .. filename, "success")
                end
            elseif adv_choice == 3 then
                io.write(ui.colors.yellow .. "Enter config file path: " .. ui.colors.reset)
                local file_path = io.read()
                
                local content = utils.readFile(file_path)
                if content then
                    local success, new_config = pcall(cjson.decode, content)
                    if success then
                        config.save(new_config)
                        ui.showMessage("Configuration imported successfully", "success")
                    else
                        ui.showMessage("Invalid configuration file", "error")
                    end
                end
            elseif adv_choice == 4 then
                print(ui.colors.yellow .. "[*] Checking for updates..." .. ui.colors.reset)
                -- This would connect to GitHub API in real implementation
                print(ui.colors.cyan .. "Current version: " .. VERSION .. ui.colors.reset)
                print(ui.colors.green .. "You have the latest version!" .. ui.colors.reset)
            elseif adv_choice == 5 then
                print(ui.colors.yellow .. "[*] Debug features coming soon..." .. ui.colors.reset)
            end
            
        elseif choice == 8 then
            break
        end
        
        ui.pressToContinue()
    end
end

-- Handle menu choice
local function handleMenuChoice(choice)
    if choice == "1" then
        -- Start Monitoring
        local config_data = config.load()
        
        if #config_data.packages == 0 then
            ui.showMessage("No packages configured!", "error")
            ui.showMessage("Please run First Configuration first", "info")
            return false
        end
        
        -- Check if auto backup is needed
        backup.performAutoBackup()
        
        -- Start monitoring
        return monitor.start(config_data)
        
    elseif choice == "2" then
        -- First Configuration
        config.setupWizard()
        return true
        
    elseif choice == "3" then
        -- Edit Configuration
        local config_data = config.load()
        if #config_data.packages == 0 then
            ui.showMessage("No configuration found!", "error")
            ui.showMessage("Please run First Configuration first", "info")
        else
            config.editMenu()
        end
        return true
        
    elseif choice == "4" then
        -- Optimize Device
        optimizer.showMenu()
        return true
        
    elseif choice == "5" then
        -- Script Manager
        script_manager.showMenu()
        return true
        
    elseif choice == "6" then
        -- Backup & Restore
        backup.showMenu()
        return true
        
    elseif choice == "7" then
        -- Tools & Utilities
        showToolsMenu()
        return true
        
    elseif choice == "8" then
        -- Uninstall
        uninstall.showMenu()
        return true
        
    elseif choice == "9" then
        -- System Info
        showSystemInfo()
        return true
        
    elseif choice == "0" then
        -- Exit
        ui.clearScreen()
        ui.printBanner(VERSION)
        print("\n" .. ui.colors.cyan .. "Thank you for using DIVINETOOLS! 👋" .. ui.colors.reset)
        
        -- Backup on exit if configured
        local config_data = config.load()
        if config_data.backup_settings and config_data.backup_settings.backup_on_exit then
            backup.backupOnExit()
        end
        
        print(ui.colors.yellow .. "\nShutting down..." .. ui.colors.reset)
        app_state.running = false
        os.exit(0)
        
    else
        ui.showMessage("Invalid selection!", "error")
        return false
    end
end

-- Main application loop
local function main()
    -- Setup signal handlers first
    setupSignalHandlers()
    
    -- Show startup banner
    ui.clearScreen()
    ui.printBanner(VERSION)
    
    print(ui.colors.cyan .. "[*] Starting DIVINETOOLS v" .. VERSION .. "..." .. ui.colors.reset)
    print(ui.colors.yellow .. "[*] Initializing..." .. ui.colors.reset)
    
    -- Check environment
    local env_ok, issues, warnings = checkEnvironment()
    if not env_ok and #issues > 0 then
        print(ui.colors.red .. "\n[FATAL] Critical issues found. Cannot continue." .. ui.colors.reset)
        print(ui.colors.yellow .. "Please fix the issues above and restart." .. ui.colors.reset)
        
        if ui.confirm("Continue anyway?", ui.colors.red) then
            -- User wants to continue despite issues
        else
            os.exit(1)
        end
    end
    
    -- Initialize modules
    if not initializeModules() then
        print(ui.colors.red .. "\n[ERROR] Failed to initialize modules. Trying to continue..." .. ui.colors.reset)
    end
    
    -- Load configuration
    local config_data = config.load()
    
    -- Check for auto-backup on start
    if config_data.backup_settings and config_data.backup_settings.auto_backup then
        print(ui.colors.cyan .. "[*] Checking for scheduled backup..." .. ui.colors.reset)
        backup.performAutoBackup()
    end
    
    print(ui.colors.green .. "\n[+] DIVINETOOLS ready!" .. ui.colors.reset)
    utils.sleep(1)
    
    -- Main application loop
    while app_state.running do
        showMainMenu()
        
        io.write(ui.colors.yellow .. "\nSelect menu (0-9): " .. ui.colors.reset)
        local choice = io.read():gsub("%s+", "")
        
        local success, err = pcall(function()
            return handleMenuChoice(choice)
        end)
        
        if not success then
            app_state.last_error = err
            print(ui.colors.red .. "\n[ERROR] " .. err .. ui.colors.reset)
            
            -- Log error
            utils.log("Menu error: " .. err, "ERROR")
            
            -- Ask if user wants to see error details
            if ui.confirm("Show error details?", ui.colors.red) then
                print(ui.colors.yellow .. "Stack trace:" .. ui.colors.reset)
                print(debug.traceback())
            end
        end
        
        -- Only pause if not exiting and choice was valid
        if choice ~= "0" and choice ~= "1" then  -- Don't pause after exit or starting monitor
            ui.pressToContinue()
        end
    end
end

-- Error handling wrapper
local function protectedMain()
    local success, err = xpcall(main, debug.traceback)
    
    if not success then
        print(ui.colors.red .. "\n[FATAL ERROR] " .. err .. ui.colors.reset)
        
        -- Log fatal error
        local log_content = os.date("[%Y-%m-%d %H:%M:%S] ") .. "FATAL: " .. err .. "\n"
        utils.writeFile("logs/crash.log", log_content)
        
        print(ui.colors.yellow .. "\nError logged to logs/crash.log" .. ui.colors.reset)
        print(ui.colors.yellow .. "Please report this issue with the log file." .. ui.colors.reset)
        
        -- Try to create emergency backup
        print(ui.colors.cyan .. "\n[*] Creating emergency backup..." .. ui.colors.reset)
        pcall(backup.backupOnExit)
        
        os.exit(1)
    end
end

-- Entry point
print(ui.colors.cyan .. "========================================" .. ui.colors.reset)
print(ui.colors.green .. "   DIVINETOOLS v2.0 - Starting..." .. ui.colors.reset)
print(ui.colors.cyan .. "========================================" .. ui.colors.reset)

-- Create necessary directories
os.execute("mkdir -p logs config scripts 2>/dev/null")

-- Start the application
protectedMain()