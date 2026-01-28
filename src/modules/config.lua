-- config.lua
-- Configuration Management Module for DIVINETOOLS

local cjson = require "cjson"
local utils = require "modules.utils"
local ui = require "modules.ui"

local M = {}

-- Paths
local CONFIG_PATH = "config/config.json"
local CONFIG_EXAMPLE_PATH = "config.example.json"

-- Default configuration
local DEFAULT_CONFIG = {
    version = "2.0",
    packages = {},
    private_servers = {
        mode = "same",
        url = "",
        urls = {}
    },
    webhook = {
        enabled = false,
        url = "",
        mode = "new",
        interval = 5,
        tag_everyone = false,
        message_id = ""
    },
    delays = {
        launch = 0,
        relaunch = 0,
        between_packages = 2
    },
    display = {
        mask_username = true,
        show_memory = true,
        show_time = true,
        refresh_rate = 0.5
    },
    optimization = {
        low_resolution = false,
        god_mode = false,
        clear_cache_on_start = true
    },
    scripts = {
        auto_inject = true,
        custom_scripts = {}
    },
    monitoring = {
        check_interval = 30,
        auto_restart = true,
        max_restart_attempts = 3
    }
}

-- Load configuration from file
function M.load()
    local file = io.open(CONFIG_PATH, "r")
    
    if not file then
        -- Create default config if doesn't exist
        print(ui.colors.yellow .. "[!] Config file not found. Creating default..." .. ui.colors.reset)
        return M.save(DEFAULT_CONFIG)
    end
    
    local content = file:read("*a")
    file:close()
    
    if content == "" then
        return M.save(DEFAULT_CONFIG)
    end
    
    local success, config = pcall(cjson.decode, content)
    if not success then
        print(ui.colors.red .. "[!] Error parsing config. Using defaults." .. ui.colors.reset)
        return DEFAULT_CONFIG
    end
    
    -- Merge with defaults for missing fields
    config = utils.tableMerge(DEFAULT_CONFIG, config)
    config.version = config.version or "1.0"
    
    return config
end

-- Save configuration to file
function M.save(config)
    -- Ensure config directory exists
    os.execute("mkdir -p config")
    
    local file = io.open(CONFIG_PATH, "w")
    if not file then
        print(ui.colors.red .. "[!] Error: Could not save config file." .. ui.colors.reset)
        return config
    end
    
    -- Pretty print JSON
    local content = cjson.encode(config)
    file:write(content)
    file:close()
    
    print(ui.colors.green .. "[+] Configuration saved." .. ui.colors.reset)
    return config
end

-- Migrate configuration from older versions
function M.migrate(old_config, target_version)
    print(ui.colors.yellow .. "[*] Migrating config from v" .. (old_config.version or "1.0") .. " to v" .. target_version .. ui.colors.reset)
    
    local new_config = utils.tableMerge(DEFAULT_CONFIG, old_config)
    new_config.version = target_version
    
    -- Migration logic for specific version changes
    if not old_config.version or old_config.version == "1.0" then
        -- Convert old structure to new
        if old_config.delay_launch then
            new_config.delays.launch = old_config.delay_launch
        end
        if old_config.delay_relaunch then
            new_config.delays.relaunch = old_config.delay_relaunch
        end
        if old_config.mask_username ~= nil then
            new_config.display.mask_username = old_config.mask_username
        end
        
        -- Migrate webhook settings
        if old_config.webhook then
            new_config.webhook.enabled = old_config.webhook.enabled or false
            new_config.webhook.url = old_config.webhook.url or ""
            new_config.webhook.mode = old_config.webhook.mode or "new"
            new_config.webhook.interval = old_config.webhook.interval or 5
            new_config.webhook.tag_everyone = old_config.webhook.tag_everyone or false
        end
    end
    
    M.save(new_config)
    return new_config
end

-- Create example config file
function M.createExample()
    local file = io.open(CONFIG_EXAMPLE_PATH, "w")
    if file then
        file:write(cjson.encode(DEFAULT_CONFIG))
        file:close()
        print(ui.colors.green .. "[+] Example config created: " .. CONFIG_EXAMPLE_PATH .. ui.colors.reset)
    end
end

-- Get username for a package
function M.getUsername(pkg)
    local cmd = string.format("timeout 2 su -c 'cat /data/data/%s/shared_prefs/prefs.xml 2>/dev/null' 2>/dev/null", pkg)
    local handle = io.popen(cmd)
    
    if not handle then return nil end
    
    local content = handle:read("*a")
    handle:close()
    
    local user = content and content:match('name="username">([^<]+)<') or nil
    if user then
        user = user:gsub("[\r\n]", "")
        user = user:gsub("%s+", "")
    end
    
    return user
end

-- Mask username for display
function M.maskUsername(username)
    if not username or #username <= 4 then
        return username or "N/A"
    end
    return username:sub(1, 3) .. "xxx" .. username:sub(-2)
end

-- Scan for Roblox packages
function M.scanPackages()
    print(ui.colors.yellow .. "[*] Scanning for com.roblox packages..." .. ui.colors.reset)
    
    local packages = {}
    local handle = io.popen("pm list packages | grep com.roblox 2>/dev/null")
    
    if handle then
        local result = handle:read("*a")
        handle:close()
        
        for line in result:gmatch("[^\r\n]+") do
            local pkg = line:match("package:(.*)")
            if pkg then
                table.insert(packages, pkg)
            end
        end
    end
    
    return packages
end

-- Show configuration in table format
function M.showConfig(config, show_details)
    ui.clearScreen()
    ui.printSeparator()
    print("        " .. ui.colors.green .. "✦ CURRENT CONFIGURATION ✦" .. ui.colors.reset)
    ui.printSeparator()
    
    -- Packages section
    print(ui.colors.iceblue .. "📦 PACKAGES (" .. #config.packages .. "):" .. ui.colors.reset)
    if #config.packages == 0 then
        print(ui.colors.red .. "  No packages configured." .. ui.colors.reset)
    else
        for i, pkg in ipairs(config.packages) do
            local user = M.getUsername(pkg)
            local display_user = user and (config.display.mask_username and M.maskUsername(user) or user) or "N/A"
            
            local url = "None"
            if config.private_servers.mode == "same" then
                url = config.private_servers.url or "None"
            elseif config.private_servers.mode == "per_package" then
                url = config.private_servers.urls[pkg] or "None"
            end
            
            if show_details then
                print(string.format("  [%d] %s", i, pkg))
                print(string.format("      User: %s", display_user))
                print(string.format("      URL:  %s", url))
            else
                print(string.format("  [%d] %s (%s)", i, pkg, display_user))
            end
        end
    end
    
    -- Private Servers
    print("\n" .. ui.colors.iceblue .. "🔗 PRIVATE SERVERS:" .. ui.colors.reset)
    print("  Mode: " .. (config.private_servers.mode == "same" and "Same URL for all" or "Different URL per package"))
    if config.private_servers.mode == "same" and config.private_servers.url ~= "" then
        print("  URL: " .. config.private_servers.url)
    end
    
    -- Webhook
    print("\n" .. ui.colors.iceblue .. "📢 WEBHOOK:" .. ui.colors.reset)
    print("  Enabled: " .. (config.webhook.enabled and ui.colors.green .. "Yes" or ui.colors.red .. "No") .. ui.colors.reset)
    if config.webhook.enabled then
        local url_display = config.webhook.url
        if #url_display > 40 then
            url_display = url_display:sub(1, 37) .. "..."
        end
        print("  URL: " .. url_display)
        print("  Mode: " .. config.webhook.mode)
        print("  Interval: " .. config.webhook.interval .. " minutes")
        print("  Tag Everyone: " .. (config.webhook.tag_everyone and "Yes" or "No"))
    end
    
    -- Delays
    print("\n" .. ui.colors.iceblue .. "⏱️ DELAYS:" .. ui.colors.reset)
    print("  Launch: " .. config.delays.launch .. "s")
    print("  Relaunch Loop: " .. config.delays.relaunch .. "m")
    print("  Between Packages: " .. config.delays.between_packages .. "s")
    
    -- Display Settings
    print("\n" .. ui.colors.iceblue .. "👁️ DISPLAY:" .. ui.colors.reset)
    print("  Mask Username: " .. (config.display.mask_username and "Yes" or "No"))
    print("  Show Memory: " .. (config.display.show_memory and "Yes" or "No"))
    print("  Show Time: " .. (config.display.show_time and "Yes" or "No"))
    print("  Refresh Rate: " .. config.display.refresh_rate .. "s")
    
    -- Monitoring
    print("\n" .. ui.colors.iceblue .. "🔍 MONITORING:" .. ui.colors.reset)
    print("  Check Interval: " .. config.monitoring.check_interval .. "s")
    print("  Auto Restart: " .. (config.monitoring.auto_restart and "Yes" or "No"))
    print("  Max Restart Attempts: " .. config.monitoring.max_restart_attempts)
    
    ui.printSeparator()
end

-- Configuration wizard for first-time setup
function M.setupWizard()
    ui.clearScreen()
    ui.printSeparator()
    print("        " .. ui.colors.green .. "✦ FIRST CONFIGURATION WIZARD ✦" .. ui.colors.reset)
    ui.printSeparator()
    
    local config = M.load()
    
    -- Check if config already exists
    if #config.packages > 0 then
        M.showConfig(config, false)
        if not ui.confirm("\nExisting configuration found. Overwrite?", ui.colors.red) then
            print(ui.colors.yellow .. "\nConfiguration cancelled." .. ui.colors.reset)
            return
        end
    end
    
    print(ui.colors.yellow .. "\nStep 1: Package Selection" .. ui.colors.reset)
    ui.printSeparator()
    
    -- Auto-detect packages
    local packages = M.scanPackages()
    
    if #packages == 0 then
        print(ui.colors.red .. "[!] No Roblox packages found!" .. ui.colors.reset)
        print("Please install Roblox from Play Store first.")
        ui.pressToContinue()
        return
    end
    
    print("Found " .. #packages .. " package(s):")
    for i, pkg in ipairs(packages) do
        print(string.format("  [%d] %s", i, pkg))
    end
    
    local selected = {}
    while true do
        print("\n" .. ui.colors.yellow .. "Select packages (e.g., 1,2,3 or 'all'): " .. ui.colors.reset)
        local input = io.read():gsub("%s+", "")
        
        if input:lower() == "all" or input == "" then
            selected = packages
            break
        elseif input:match("^[%d,]+$") then
            local indices = {}
            for str in input:gmatch("[^,]+") do
                local idx = tonumber(str)
                if idx and idx >= 1 and idx <= #packages then
                    if not utils.tableContains(indices, idx) then
                        table.insert(indices, idx)
                    end
                end
            end
            
            if #indices > 0 then
                for _, idx in ipairs(indices) do
                    table.insert(selected, packages[idx])
                end
                break
            end
        end
        
        print(ui.colors.red .. "[!] Invalid selection. Try again." .. ui.colors.reset)
    end
    
    config.packages = selected
    print(ui.colors.green .. "[+] Selected " .. #selected .. " package(s)." .. ui.colors.reset)
    
    -- Private Server Configuration
    ui.printSeparator()
    print(ui.colors.yellow .. "\nStep 2: Private Server Configuration" .. ui.colors.reset)
    ui.printSeparator()
    
    print("Private Server Options:")
    print("  1. Same URL for all packages")
    print("  2. Different URL for each package")
    print("  3. No private server (skip)")
    
    local ps_choice = ui.getNumberInput("Select option (1-3): ", 1, 3)
    
    if ps_choice == 1 then
        config.private_servers.mode = "same"
        print(ui.colors.yellow .. "Enter private server URL:" .. ui.colors.reset)
        config.private_servers.url = io.read()
        config.private_servers.urls = {}
    elseif ps_choice == 2 then
        config.private_servers.mode = "per_package"
        config.private_servers.url = ""
        config.private_servers.urls = {}
        
        print(ui.colors.yellow .. "Enter URL for each package:" .. ui.colors.reset)
        for _, pkg in ipairs(config.packages) do
            local user = M.getUsername(pkg)
            local display = user and (pkg .. " (" .. user .. ")") or pkg
            io.write("  " .. display .. ": ")
            local url = io.read()
            if url and url ~= "" then
                config.private_servers.urls[pkg] = url
            end
        end
    else
        config.private_servers.mode = "same"
        config.private_servers.url = ""
        config.private_servers.urls = {}
    end
    
    -- Webhook Configuration
    ui.printSeparator()
    print(ui.colors.yellow .. "\nStep 3: Webhook Configuration (Optional)" .. ui.colors.reset)
    ui.printSeparator()
    
    if ui.confirm("Enable Discord webhook notifications?", ui.colors.yellow) then
        config.webhook.enabled = true
        
        print(ui.colors.yellow .. "Enter webhook URL:" .. ui.colors.reset)
        config.webhook.url = io.read()
        
        print("\nWebhook Mode:")
        print("  1. Send new message for each update")
        print("  2. Edit previous message")
        local mode_choice = ui.getNumberInput("Select mode (1-2): ", 1, 2)
        config.webhook.mode = mode_choice == 2 and "edit" or "new"
        
        config.webhook.interval = ui.getNumberInput("Update interval (minutes, min 5): ", 5, 1440)
        config.webhook.tag_everyone = ui.confirm("Tag @everyone in alerts?", ui.colors.yellow)
    else
        config.webhook.enabled = false
    end
    
    -- Display Settings
    ui.printSeparator()
    print(ui.colors.yellow .. "\nStep 4: Display Settings" .. ui.colors.reset)
    ui.printSeparator()
    
    config.display.mask_username = ui.confirm("Mask usernames in display?", ui.colors.yellow)
    config.display.show_memory = ui.confirm("Show memory usage?", ui.colors.yellow)
    config.display.show_time = ui.confirm("Show current time?", ui.colors.yellow)
    
    -- Delay Settings
    ui.printSeparator()
    print(ui.colors.yellow .. "\nStep 5: Delay Settings" .. ui.colors.reset)
    ui.printSeparator()
    
    config.delays.launch = ui.getNumberInput("Delay between launching packages (seconds): ", 0, 60)
    config.delays.relaunch = ui.getNumberInput("Relaunch loop delay (minutes, 0=no loop): ", 0, 1440)
    config.delays.between_packages = ui.getNumberInput("Delay between packages (seconds): ", 0, 30)
    
    -- Optimization Settings
    ui.printSeparator()
    print(ui.colors.yellow .. "\nStep 6: Optimization Settings" .. ui.colors.reset)
    ui.printSeparator()
    
    config.optimization.clear_cache_on_start = ui.confirm("Clear cache on start?", ui.colors.yellow)
    config.optimization.low_resolution = ui.confirm("Use low resolution mode?", ui.colors.yellow)
    
    if ui.confirm("Enable GOD MODE (extreme optimization)?", ui.colors.red) then
        config.optimization.god_mode = true
        print(ui.colors.yellow .. "[!] Warning: GOD MODE will remove textures and disable animations." .. ui.colors.reset)
    end
    
    -- Save configuration
    ui.printSeparator()
    print(ui.colors.yellow .. "\nStep 7: Save Configuration" .. ui.colors.reset)
    ui.printSeparator()
    
    M.save(config)
    M.showConfig(config, false)
    
    print(ui.colors.green .. "\n[+] First configuration completed successfully!" .. ui.colors.reset)
    print(ui.colors.green .. "[+] Run 'Start Monitoring' to begin." .. ui.colors.reset)
end

-- Edit configuration menu
function M.editMenu()
    local config = M.load()
    
    while true do
        ui.clearScreen()
        ui.printSeparator()
        print("        " .. ui.colors.green .. "✦ EDIT CONFIGURATION ✦" .. ui.colors.reset)
        ui.printSeparator()
        
        print("  [1] Packages List")
        print("  [2] Private Servers")
        print("  [3] Webhook Settings")
        print("  [4] Delay Settings")
        print("  [5] Display Settings")
        print("  [6] Optimization Settings")
        print("  [7] Show Full Config")
        print("  [8] Save & Exit")
        print("  [9] Exit Without Saving")
        
        ui.printSeparator()
        
        local choice = ui.getNumberInput("Select option (1-9): ", 1, 9)
        
        if choice == 1 then
            M.editPackages(config)
        elseif choice == 2 then
            M.editPrivateServers(config)
        elseif choice == 3 then
            M.editWebhook(config)
        elseif choice == 4 then
            M.editDelays(config)
        elseif choice == 5 then
            M.editDisplay(config)
        elseif choice == 6 then
            M.editOptimization(config)
        elseif choice == 7 then
            M.showConfig(config, true)
            ui.pressToContinue()
        elseif choice == 8 then
            M.save(config)
            print(ui.colors.green .. "[+] Configuration saved." .. ui.colors.reset)
            break
        elseif choice == 9 then
            if ui.confirm("Discard changes?", ui.colors.red) then
                break
            end
        end
    end
end

-- Sub-functions for edit menu
function M.editPackages(config)
    ui.clearScreen()
    ui.printSeparator()
    print("        " .. ui.colors.green .. "✦ EDIT PACKAGES ✦" .. ui.colors.reset)
    ui.printSeparator()
    
    print("Current packages (" .. #config.packages .. "):")
    for i, pkg in ipairs(config.packages) do
        print(string.format("  [%d] %s", i, pkg))
    end
    
    print("\nOptions:")
    print("  [1] Add packages")
    print("  [2] Remove packages")
    print("  [3] Scan for new packages")
    print("  [4] Clear all packages")
    print("  [5] Back")
    
    local choice = ui.getNumberInput("Select option (1-5): ", 1, 5)
    
    if choice == 1 then
        local packages = M.scanPackages()
        if #packages == 0 then
            print(ui.colors.red .. "[!] No packages found." .. ui.colors.reset)
        else
            print("Available packages:")
            for i, pkg in ipairs(packages) do
                if not utils.tableContains(config.packages, pkg) then
                    print(string.format("  [%d] %s", i, pkg))
                end
            end
        end
    elseif choice == 2 and #config.packages > 0 then
        local idx = ui.getNumberInput("Enter package number to remove: ", 1, #config.packages)
        table.remove(config.packages, idx)
        print(ui.colors.green .. "[+] Package removed." .. ui.colors.reset)
    elseif choice == 3 then
        config.packages = M.scanPackages()
        print(ui.colors.green .. "[+] Rescanned packages." .. ui.colors.reset)
    elseif choice == 4 then
        if ui.confirm("Clear ALL packages?", ui.colors.red) then
            config.packages = {}
            print(ui.colors.green .. "[+] All packages cleared." .. ui.colors.reset)
        end
    end
    
    ui.pressToContinue()
end

function M.editPrivateServers(config)
    -- Implementation similar to original but modular
    -- (Would continue with similar pattern)
end

function M.editWebhook(config)
    -- Implementation similar to original but modular
end

function M.editDelays(config)
    -- Implementation similar to original but modular
end

function M.editDisplay(config)
    -- Implementation similar to original but modular
end

function M.editOptimization(config)
    -- Implementation similar to original but modular
end

return M