-- script_manager.lua
-- Script Injection and Management Module for DIVINETOOLS

local config = require("modules.config")
local ui = require("modules.ui")
local utils = require("modules.utils")
local cjson = require("cjson")

local M = {}

-- Script directories
local SCRIPT_DIRS = {
    DELTA = "/storage/emulated/0/Delta/Autoexecute",
    FLUXUS = "/storage/emulated/0/FluxusZ/autoexec",
    HYDROGEN = "/storage/emulated/0/Hydrogen/scripts",
    KRNL = "/storage/emulated/0/Krnl/scripts",
    SYNAPSE = "/storage/emulated/0/Synapse/scripts",
    OXYGEN = "/storage/emulated/0/Oxygen/scripts",
    CUSTOM = "/storage/emulated/0/DivineScripts"
}

-- Supported executors
local SUPPORTED_EXECUTORS = {
    "Delta",
    "Fluxus", 
    "Hydrogen",
    "Krnl",
    "Synapse",
    "Oxygen",
    "Custom"
}

-- Script categories
local SCRIPT_CATEGORIES = {
    MONITOR = "Monitoring",
    OPTIMIZATION = "Optimization",
    UTILITY = "Utility",
    AUTOFARM = "Auto Farm",
    ANTI_AFK = "Anti AFK",
    TELEPORT = "Teleport",
    GUI = "GUI",
    OTHER = "Other"
}

-- Default scripts library
local DEFAULT_SCRIPTS = {
    {
        id = "divine_monitor",
        name = "Divine Monitor Core",
        description = "Core monitoring script for webhook integration",
        category = SCRIPT_CATEGORIES.MONITOR,
        content = [[
-- Divine Monitor v2.0
-- Auto-injected by DIVINETOOLS

local DVN_CONFIG = {
    WEBHOOK_URL = "{{WEBHOOK_URL}}",
    MENTION_EVERYONE = {{TAG_EVERYONE}},
    UPDATE_INTERVAL = {{UPDATE_INTERVAL}},
    PACKAGE_NAME = "{{PACKAGE_NAME}}"
}

-- Load HTTP library
local success, http = pcall(function()
    return game:GetService("HttpService")
end)

if not success then
    warn("[Divine] HttpService not available")
    return
end

-- Send status update
local function sendStatus(status, extra)
    if not DVN_CONFIG.WEBHOOK_URL or DVN_CONFIG.WEBHOOK_URL == "" then
        return
    end
    
    local payload = {
        content = DVN_CONFIG.MENTION_EVERYONE and "@everyone" or nil,
        embeds = {{
            title = "🎮 Roblox Status Update",
            description = string.format("**Package:** %s\n**Status:** %s", 
                DVN_CONFIG.PACKAGE_NAME, status),
            color = 7419530,
            fields = extra or {},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
    
    pcall(function()
        http:PostAsync(DVN_CONFIG.WEBHOOK_URL, http:JSONEncode(payload))
    end)
end

-- Game join detection
game:GetService("Players").PlayerAdded:Connect(function(player)
    if player == game:GetService("Players").LocalPlayer then
        sendStatus("JOINED_GAME", {
            {
                name = "🎯 Game",
                value = game.PlaceId,
                inline = true
            },
            {
                name = "👤 Player",
                value = player.Name,
                inline = true
            },
            {
                name = "🕒 Time",
                value = os.date("%H:%M:%S"),
                inline = true
            }
        })
        
        -- Periodic updates
        while task.wait(DVN_CONFIG.UPDATE_INTERVAL * 60) do
            sendStatus("ONLINE", {
                {
                    name = "⏱️ Uptime",
                    value = string.format("%d minutes", 
                        math.floor(tick() / 60)),
                    inline = true
                }
            })
        end
    end
end)

-- Game leave detection
game:GetService("Players").PlayerRemoving:Connect(function(player)
    if player == game:GetService("Players").LocalPlayer then
        sendStatus("LEFT_GAME")
    end
end)

print("[Divine] Monitor initialized for " .. DVN_CONFIG.PACKAGE_NAME)
]],
        variables = {
            "WEBHOOK_URL",
            "TAG_EVERYONE", 
            "UPDATE_INTERVAL",
            "PACKAGE_NAME"
        }
    },
    {
        id = "anti_afk",
        name = "Anti AFK System",
        description = "Prevents AFK detection in Roblox",
        category = SCRIPT_CATEGORIES.ANTI_AFK,
        content = [[
-- Divine Anti-AFK System
-- Prevents AFK detection

local VirtualInput = game:GetService("VirtualInputManager")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function moveCharacter()
    if LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            -- Small movement
            humanoid:Move(Vector3.new(
                math.random(-10, 10) / 100,
                0,
                math.random(-10, 10) / 100
            ))
        end
    end
end

local function simulateInput()
    -- Simulate mouse movement
    VirtualInput:SendMouseMoveEvent(
        math.random(100, 500),
        math.random(100, 500)
    )
    
    -- Simulate key press
    VirtualInput:SendKeyEvent(true, Enum.KeyCode.Space, false, nil)
    task.wait(0.1)
    VirtualInput:SendKeyEvent(false, Enum.KeyCode.Space, false, nil)
end

-- Random interval between 2-5 minutes
while task.wait(math.random(120, 300)) do
    pcall(function()
        if math.random(1, 2) == 1 then
            moveCharacter()
        else
            simulateInput()
        end
        print("[Anti-AFK] Activity simulated at " .. os.date("%H:%M:%S"))
    end)
end
]]
    },
    {
        id = "auto_rejoin",
        name = "Auto Rejoin",
        description = "Automatically rejoins game if disconnected",
        category = SCRIPT_CATEGORIES.UTILITY,
        content = [[
-- Divine Auto Rejoin
-- Automatically rejoins on disconnect

local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local placeId = game.PlaceId
local jobId = game.JobId

local function rejoin()
    pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, jobId)
    end)
end

-- Connection lost detection
game:GetService("NetworkClient").ConnectionFailed:Connect(function()
    print("[AutoRejoin] Connection lost, attempting to rejoin...")
    task.wait(5) -- Wait 5 seconds
    rejoin()
end)

-- Manual rejoin command
local function setupCommand()
    Players.LocalPlayer.Chatted:Connect(function(message)
        if message:lower() == "!rejoin" then
            rejoin()
        end
    end)
end

setupCommand()
print("[AutoRejoin] System initialized for PlaceId: " .. placeId)
]]
    }
}

-- Check if executor is installed
function M.isExecutorInstalled(executor_name)
    local dir = SCRIPT_DIRS[executor_name:upper()]
    if not dir then
        return false
    end
    
    -- Check if directory exists
    local cmd = string.format("test -d '%s' && echo 'exists'", dir)
    local result = utils.captureCommand(cmd)
    
    return result and result:match("exists") ~= nil
end

-- Get available executors
function M.getAvailableExecutors()
    local available = {}
    
    for _, executor in ipairs(SUPPORTED_EXECUTORS) do
        if M.isExecutorInstalled(executor) then
            table.insert(available, executor)
        end
    end
    
    -- Always include Custom directory
    if not utils.tableContains(available, "Custom") then
        table.insert(available, "Custom")
    end
    
    return available
end

-- Get script directory for executor
function M.getScriptDir(executor_name)
    if executor_name == "Custom" then
        return SCRIPT_DIRS.CUSTOM
    end
    
    local dir = SCRIPT_DIRS[executor_name:upper()]
    if not dir then
        return SCRIPT_DIRS.CUSTOM
    end
    
    return dir
end

-- Create script directory
function M.createScriptDir(executor_name)
    local dir = M.getScriptDir(executor_name)
    return utils.createDirectory(dir)
end

-- List scripts in directory
function M.listScripts(executor_name)
    local dir = M.getScriptDir(executor_name)
    local scripts = {}
    
    if not M.isExecutorInstalled(executor_name) then
        return scripts
    end
    
    local files = utils.listFiles(dir, "*.lua")
    for _, file in ipairs(files) do
        local name = file:match("([^/]+)%.lua$") or file:match("([^/]+)$")
        local size = utils.getFileSize(file)
        
        table.insert(scripts, {
            name = name,
            path = file,
            size = size,
            executor = executor_name
        })
    end
    
    -- Also check .txt files (common for some executors)
    local txt_files = utils.listFiles(dir, "*.txt")
    for _, file in ipairs(txt_files) do
        local name = file:match("([^/]+)%.txt$") or file:match("([^/]+)$")
        local size = utils.getFileSize(file)
        
        table.insert(scripts, {
            name = name,
            path = file,
            size = size,
            executor = executor_name,
            extension = ".txt"
        })
    end
    
    return scripts
end

-- Read script content
function M.readScript(file_path)
    return utils.readFile(file_path)
end

-- Save script
function M.saveScript(executor_name, script_name, content, overwrite)
    local dir = M.getScriptDir(executor_name)
    M.createScriptDir(executor_name)
    
    -- Add .lua extension if not present
    if not script_name:match("%.lua$") and not script_name:match("%.txt$") then
        script_name = script_name .. ".lua"
    end
    
    local file_path = dir .. "/" .. script_name
    
    -- Check if file exists
    if not overwrite and utils.fileExists(file_path) then
        return false, "Script already exists. Use overwrite option."
    end
    
    local success, err = utils.writeFile(file_path, content)
    if success then
        return true, file_path
    else
        return false, err
    end
end

-- Delete script
function M.deleteScript(file_path)
    if not utils.fileExists(file_path) then
        return false, "Script file not found"
    end
    
    local success = os.execute("rm -f " .. utils.escapeShellArg(file_path))
    if success then
        return true, "Script deleted"
    else
        return false, "Failed to delete script"
    end
end

-- Backup script
function M.backupScript(file_path)
    if not utils.fileExists(file_path) then
        return false, "Script file not found"
    end
    
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local backup_path = file_path .. ".backup_" .. timestamp
    
    local success, err = utils.copy(file_path, backup_path)
    if success then
        return true, backup_path
    else
        return false, err
    end
end

-- Create divine monitor script
function M.createDivineMonitorScript(config_data, package_name)
    if not config_data.webhook.enabled then
        return false, "Webhook not enabled in config"
    end
    
    local template = DEFAULT_SCRIPTS[1].content  -- divine_monitor script
    
    -- Replace variables
    local script_content = template
        :gsub("{{WEBHOOK_URL}}", config_data.webhook.url or "")
        :gsub("{{TAG_EVERYONE}}", tostring(config_data.webhook.tag_everyone))
        :gsub("{{UPDATE_INTERVAL}}", tostring(config_data.webhook.interval or 5))
        :gsub("{{PACKAGE_NAME}}", package_name)
    
    -- Get available executors
    local executors = M.getAvailableExecutors()
    if #executors == 0 then
        return false, "No supported executors found"
    end
    
    -- Save to all available executors
    local saved_to = {}
    for _, executor in ipairs(executors) do
        local script_name = "DivineMonitor_" .. package_name:gsub("%.", "_")
        local success, result = M.saveScript(executor, script_name, script_content, true)
        
        if success then
            table.insert(saved_to, executor)
        end
    end
    
    if #saved_to > 0 then
        return true, "Saved to: " .. table.concat(saved_to, ", ")
    else
        return false, "Failed to save to any executor"
    end
end

-- Inject script to all executors
function M.injectScriptToAll(script_name, script_content)
    local executors = M.getAvailableExecutors()
    local results = {}
    
    for _, executor in ipairs(executors) do
        local success, result = M.saveScript(executor, script_name, script_content, true)
        
        table.insert(results, {
            executor = executor,
            success = success,
            message = result
        })
    end
    
    return results
end

-- Get script info
function M.getScriptInfo(file_path)
    local content = M.readScript(file_path)
    if not content then
        return nil
    end
    
    local info = {
        path = file_path,
        size = utils.getFileSize(file_path),
        lines = #(content:gsub("[^\n]", "")) + 1,
        created = nil,
        modified = nil
    }
    
    -- Try to get file stats
    local stats_cmd = string.format("stat -c '%%Y|%%y' '%s' 2>/dev/null", file_path)
    local stats = utils.captureCommand(stats_cmd)
    
    if stats then
        local timestamp, date = stats:match("(%d+)|(.+)")
        if timestamp then
            info.modified = os.date("%Y-%m-%d %H:%M:%S", tonumber(timestamp))
        end
    end
    
    -- Try to detect script type from content
    if content:match("getgenv%(%)") or content:match("loadstring") then
        info.type = "Executor Script"
    elseif content:match("LocalScript") or content:match("ModuleScript") then
        info.type = "Roblox Script"
    else
        info.type = "Unknown"
    end
    
    -- Extract metadata comments
    local metadata = {}
    for line in content:gmatch("[^\n]+") do
        local key, value = line:match("%-%-%s*@(%w+)%s*:%s*(.+)")
        if key and value then
            metadata[key] = value
        end
    end
    
    if next(metadata) ~= nil then
        info.metadata = metadata
    end
    
    return info
end

-- Validate script syntax (basic)
function M.validateScript(content)
    if not content or content == "" then
        return false, "Script content is empty"
    end
    
    -- Check for potentially dangerous patterns
    local dangerous_patterns = {
        "os%.execute%(",
        "io%.popen%(",
        "shell%.execute%(",
        "loadstring%(io%.open%(",
        "while true do"
    }
    
    for _, pattern in ipairs(dangerous_patterns) do
        if content:match(pattern) then
            return false, "Script contains potentially dangerous pattern: " .. pattern
        end
    end
    
    -- Check for infinite loops without delays
    if content:match("while true do") and not content:match("wait%(") and not content:match("task%.wait%(") then
        return false, "Script may contain infinite loop without delay"
    end
    
    return true, "Script appears valid"
end

-- Format script content
function M.formatScript(content)
    -- Basic formatting: trim trailing spaces
    local lines = {}
    for line in content:gmatch("[^\n]+") do
        table.insert(lines, line:gsub("%s+$", ""))
    end
    
    -- Remove consecutive empty lines (keep max 2)
    local formatted = {}
    local empty_count = 0
    
    for _, line in ipairs(lines) do
        if line:match("^%s*$") then
            empty_count = empty_count + 1
            if empty_count <= 2 then
                table.insert(formatted, line)
            end
        else
            empty_count = 0
            table.insert(formatted, line)
        end
    end
    
    return table.concat(formatted, "\n")
end

-- Search scripts
function M.searchScripts(search_term, executor_name)
    local scripts = M.listScripts(executor_name or "Custom")
    local results = {}
    
    for _, script in ipairs(scripts) do
        local content = M.readScript(script.path)
        if content then
            if script.name:lower():find(search_term:lower()) or
               content:lower():find(search_term:lower()) then
                table.insert(results, script)
            end
        end
    end
    
    return results
end

-- Import script from URL
function M.importFromURL(url, script_name)
    print(ui.colors.yellow .. "[*] Downloading script from URL..." .. ui.colors.reset)
    
    local cmd = string.format("curl -s -L '%s'", url)
    local content = utils.captureCommand(cmd)
    
    if not content or content == "" then
        return false, "Failed to download from URL"
    end
    
    -- Validate the downloaded content
    local valid, message = M.validateScript(content)
    if not valid then
        return false, "Downloaded script validation failed: " .. message
    end
    
    -- Format the script
    content = M.formatScript(content)
    
    -- Save to Custom directory
    return M.saveScript("Custom", script_name, content, true)
end

-- Export script collection
function M.exportCollection(scripts, format)
    format = format or "zip"
    
    if format == "zip" then
        -- Create temporary directory
        local temp_dir = "/data/local/tmp/divine_scripts_" .. os.date("%Y%m%d_%H%M%S")
        utils.createDirectory(temp_dir)
        
        -- Copy scripts to temp directory
        for _, script in ipairs(scripts) do
            if utils.fileExists(script.path) then
                local dest = temp_dir .. "/" .. script.name
                utils.copy(script.path, dest)
            end
        end
        
        -- Create zip
        local zip_file = "/storage/emulated/0/Download/divine_scripts.zip"
        local success = utils.compressToZip(temp_dir, zip_file)
        
        -- Cleanup
        utils.removeDirectory(temp_dir)
        
        if success then
            return true, zip_file
        else
            return false, "Failed to create zip file"
        end
    elseif format == "json" then
        local collection = {
            exported_at = os.time(),
            script_count = #scripts,
            scripts = {}
        }
        
        for _, script in ipairs(scripts) do
            local content = M.readScript(script.path)
            if content then
                table.insert(collection.scripts, {
                    name = script.name,
                    content = content,
                    executor = script.executor,
                    size = script.size
                })
            end
        end
        
        local json_data = cjson.encode(collection)
        local file_path = "/storage/emulated/0/Download/divine_scripts.json"
        
        local success, err = utils.writeFile(file_path, json_data)
        if success then
            return true, file_path
        else
            return false, err
        end
    end
    
    return false, "Unsupported export format"
end

-- Show script manager menu
function M.showMenu()
    while true do
        ui.clearScreen()
        ui.printSeparator(54, "═", ui.colors.cyan)
        print("        " .. ui.colors.green .. "✦ SCRIPT MANAGER ✦" .. ui.colors.reset)
        ui.printSeparator(54, "═", ui.colors.cyan)
        
        print(ui.colors.cyan .. "  [1] View Scripts" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Browse and manage scripts" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [2] Create New Script" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Create a new script from template" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [3] Edit Script" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Edit existing script" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [4] Delete Script" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Delete scripts" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [5] Import Script" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Import from URL or file" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [6] Export Scripts" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Export script collection" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [7] Script Templates" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Use pre-made templates" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [8] Executor Setup" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Configure executor directories" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [9] Back to Main Menu" .. ui.colors.reset)
        
        ui.printSeparator(54, "═", ui.colors.cyan)
        
        local choice = ui.getNumberInput("\nSelect option (1-9): ", 1, 9)
        
        if choice == 1 then
            M.showScriptBrowser()
        elseif choice == 2 then
            M.createScriptWizard()
        elseif choice == 3 then
            M.editScriptMenu()
        elseif choice == 4 then
            M.deleteScriptMenu()
        elseif choice == 5 then
            M.importScriptMenu()
        elseif choice == 6 then
            M.exportScriptMenu()
        elseif choice == 7 then
            M.showTemplatesMenu()
        elseif choice == 8 then
            M.executorSetupMenu()
        elseif choice == 9 then
            break
        end
        
        ui.pressToContinue()
    end
end

-- Show script browser
function M.showScriptBrowser()
    local executors = M.getAvailableExecutors()
    
    if #executors == 0 then
        ui.showMessage("No executors found. Please install an executor first.", "warning")
        return
    end
    
    ui.clearScreen()
    ui.printSeparator(54, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "✦ SCRIPT BROWSER ✦" .. ui.colors.reset)
    ui.printSeparator(54, "═", ui.colors.cyan)
    
    print(ui.colors.yellow .. "Available Executors:" .. ui.colors.reset)
    for i, executor in ipairs(executors) do
        print(string.format("  [%d] %s", i, executor))
    end
    
    print()
    local executor_idx = ui.getNumberInput("Select executor (1-" .. #executors .. "): ", 1, #executors)
    local executor_name = executors[executor_idx]
    
    -- List scripts
    local scripts = M.listScripts(executor_name)
    
    if #scripts == 0 then
        ui.showMessage("No scripts found in " .. executor_name, "info")
        return
    end
    
    -- Display scripts
    ui.clearScreen()
    ui.printSeparator(60, "═", ui.colors.green)
    print("        " .. ui.colors.cyan .. "SCRIPTS IN " .. executor_name:upper() .. ui.colors.reset)
    ui.printSeparator(60, "═", ui.colors.green)
    
    local headers = {"#", "Name", "Size", "Path"}
    local rows = {}
    
    for i, script in ipairs(scripts) do
        local size_str = script.size > 1024 and 
            string.format("%.1f KB", script.size / 1024) or
            string.format("%d B", script.size)
        
        local display_path = script.path
        if #display_path > 40 then
            display_path = "..." .. script.path:sub(-37)
        end
        
        table.insert(rows, {i, script.name, size_str, display_path})
    end
    
    ui.displayTable(headers, rows, "Total: " .. #scripts .. " scripts")
    
    -- Script actions
    print()
    print(ui.colors.yellow .. "Actions:" .. ui.colors.reset)
    print("  [v] View script content")
    print("  [e] Edit script")
    print("  [d] Delete script")
    print("  [b] Backup script")
    print("  [q] Back")
    
    io.write(ui.colors.yellow .. "\nSelect action: " .. ui.colors.reset)
    local action = io.read():lower()
    
    if action == "v" then
        local script_idx = ui.getNumberInput("Enter script number to view: ", 1, #scripts)
        local script = scripts[script_idx]
        M.viewScriptContent(script.path)
    elseif action == "e" then
        local script_idx = ui.getNumberInput("Enter script number to edit: ", 1, #scripts)
        local script = scripts[script_idx]
        M.editScript(script.path)
    elseif action == "d" then
        local script_idx = ui.getNumberInput("Enter script number to delete: ", 1, #scripts)
        local script = scripts[script_idx]
        M.deleteScriptPrompt(script.path)
    elseif action == "b" then
        local script_idx = ui.getNumberInput("Enter script number to backup: ", 1, #scripts)
        local script = scripts[script_idx]
        M.backupScriptPrompt(script.path)
    end
end

-- View script content
function M.viewScriptContent(file_path)
    local content = M.readScript(file_path)
    if not content then
        ui.showMessage("Failed to read script file", "error")
        return
    end
    
    ui.clearScreen()
    ui.printSeparator(80, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "SCRIPT CONTENT: " .. file_path .. ui.colors.reset)
    ui.printSeparator(80, "═", ui.colors.cyan)
    
    -- Show with line numbers
    local lines = {}
    for line in content:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    
    for i = 1, math.min(50, #lines) do  -- Show first 50 lines
        print(string.format("%4d: %s", i, lines[i]))
    end
    
    if #lines > 50 then
        print(ui.colors.yellow .. "\n... " .. (#lines - 50) .. " more lines not shown" .. ui.colors.reset)
    end
    
    -- Show script info
    local info = M.getScriptInfo(file_path)
    if info then
        ui.printSeparator(80, "─", ui.colors.yellow)
        print(ui.colors.cyan .. "Script Information:" .. ui.colors.reset)
        print("  Size: " .. info.size .. " bytes")
        print("  Lines: " .. info.lines)
        print("  Type: " .. info.type)
        if info.modified then
            print("  Modified: " .. info.modified)
        end
    end
    
    ui.printSeparator(80, "═", ui.colors.cyan)
end

-- Edit script
function M.editScript(file_path)
    local content = M.readScript(file_path)
    if not content then
        ui.showMessage("Failed to read script file", "error")
        return
    end
    
    ui.clearScreen()
    ui.printSeparator(80, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "EDIT SCRIPT: " .. file_path .. ui.colors.reset)
    ui.printSeparator(80, "═", ui.colors.cyan)
    
    print(ui.colors.yellow .. "Current content (first 1000 chars):" .. ui.colors.reset)
    print(ui.colors.white .. content:sub(1, 1000) .. ui.colors.reset)
    if #content > 1000 then
        print(ui.colors.yellow .. "... " .. (#content - 1000) .. " more characters" .. ui.colors.reset)
    end
    
    print()
    print(ui.colors.yellow .. "Options:" .. ui.colors.reset)
    print("  [1] Edit in terminal")
    print("  [2] Replace entire script")
    print("  [3] Format script")
    print("  [4] Validate script")
    print("  [5] Cancel")
    
    local choice = ui.getNumberInput("\nSelect option (1-5): ", 1, 5)
    
    if choice == 1 then
        -- Use system editor
        os.execute("nano " .. utils.escapeShellArg(file_path))
        ui.showMessage("Script saved with nano editor", "success")
        
    elseif choice == 2 then
        print(ui.colors.yellow .. "\nEnter new script content. Type 'END' on a new line to finish:" .. ui.colors.reset)
        
        local lines = {}
        while true do
            local line = io.read()
            if line == "END" then
                break
            end
            table.insert(lines, line)
        end
        
        local new_content = table.concat(lines, "\n")
        
        -- Validate
        local valid, message = M.validateScript(new_content)
        if not valid then
            ui.showMessage("Validation failed: " .. message, "error")
            if not ui.confirm("Save anyway?", ui.colors.red) then
                return
            end
        end
        
        -- Format
        new_content = M.formatScript(new_content)
        
        -- Save
        local success, err = utils.writeFile(file_path, new_content)
        if success then
            ui.showMessage("Script replaced successfully", "success")
        else
            ui.showMessage("Failed to save: " .. err, "error")
        end
        
    elseif choice == 3 then
        local formatted = M.formatScript(content)
        local success, err = utils.writeFile(file_path, formatted)
        if success then
            ui.showMessage("Script formatted successfully", "success")
        else
            ui.showMessage("Failed to format: " .. err, "error")
        end
        
    elseif choice == 4 then
        local valid, message = M.validateScript(content)
        if valid then
            ui.showMessage("Script validation passed: " .. message, "success")
        else
            ui.showMessage("Script validation failed: " .. message, "error")
        end
    end
end

-- Create script wizard
function M.createScriptWizard()
    ui.clearScreen()
    ui.printSeparator(54, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "✦ CREATE NEW SCRIPT ✦" .. ui.colors.reset)
    ui.printSeparator(54, "═", ui.colors.cyan)
    
    -- Get executor
    local executors = M.getAvailableExecutors()
    if #executors == 0 then
        ui.showMessage("No executors available. Using Custom directory.", "warning")
        executors = {"Custom"}
    end
    
    print(ui.colors.yellow .. "Select executor:" .. ui.colors.reset)
    for i, executor in ipairs(executors) do
        print(string.format("  [%d] %s", i, executor))
    end
    
    local executor_idx = ui.getNumberInput("\nSelect executor (1-" .. #executors .. "): ", 1, #executors)
    local executor_name = executors[executor_idx]
    
    -- Get script name
    io.write(ui.colors.yellow .. "\nEnter script name (without extension): " .. ui.colors.reset)
    local script_name = io.read():gsub("%s+", "")
    
    if script_name == "" then
        ui.showMessage("Script name cannot be empty", "error")
        return
    end
    
    -- Get script content
    print(ui.colors.yellow .. "\nEnter script content. Type 'END' on a new line to finish:" .. ui.colors.reset)
    print(ui.colors.cyan .. "  (You can paste multiple lines)" .. ui.colors.reset)
    
    local lines = {}
    while true do
        local line = io.read()
        if line == "END" then
            break
        end
        table.insert(lines, line)
    end
    
    local content = table.concat(lines, "\n")
    
    if content == "" then
        ui.showMessage("Script content cannot be empty", "error")
        return
    end
    
    -- Validate
    local valid, message = M.validateScript(content)
    if not valid then
        ui.showMessage("Validation warning: " .. message, "warning")
        if not ui.confirm("Continue anyway?", ui.colors.yellow) then
            return
        end
    end
    
    -- Format
    content = M.formatScript(content)
    
    -- Save
    local success, result = M.saveScript(executor_name, script_name, content, false)
    
    if success then
        ui.showMessage("Script created successfully: " .. result, "success")
        
        -- Ask to edit
        if ui.confirm("Edit script now?", ui.colors.cyan) then
            M.editScript(result)
        end
    else
        ui.showMessage("Failed to create script: " .. result, "error")
    end
end

-- Delete script prompt
function M.deleteScriptPrompt(file_path)
    if not ui.confirm("Are you sure you want to delete this script?", ui.colors.red) then
        return
    end
    
    -- Backup first
    if ui.confirm("Create backup before deleting?", ui.colors.yellow) then
        local success, backup_path = M.backupScript(file_path)
        if success then
            ui.showMessage("Backup created: " .. backup_path, "success")
        end
    end
    
    local success, message = M.deleteScript(file_path)
    if success then
        ui.showMessage("Script deleted: " .. message, "success")
    else
        ui.showMessage("Failed to delete: " .. message, "error")
    end
end

-- Backup script prompt
function M.backupScriptPrompt(file_path)
    local success, backup_path = M.backupScript(file_path)
    if success then
        ui.showMessage("Backup created: " .. backup_path, "success")
    else
        ui.showMessage("Failed to create backup: " .. backup_path, "error")
    end
end

-- Import script menu
function M.importScriptMenu()
    ui.clearScreen()
    ui.printSeparator(54, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "✦ IMPORT SCRIPT ✦" .. ui.colors.reset)
    ui.printSeparator(54, "═", ui.colors.cyan)
    
    print(ui.colors.yellow .. "Import from:" .. ui.colors.reset)
    print("  [1] URL (pastebin, github, etc)")
    print("  [2] Local file")
    print("  [3] Cancel")
    
    local choice = ui.getNumberInput("\nSelect option (1-3): ", 1, 3)
    
    if choice == 1 then
        io.write(ui.colors.yellow .. "\nEnter URL: " .. ui.colors.reset)
        local url = io.read():gsub("%s+", "")
        
        io.write(ui.colors.yellow .. "Enter script name: " .. ui.colors.reset)
        local script_name = io.read():gsub("%s+", "")
        
        if url and script_name then
            local success, result = M.importFromURL(url, script_name)
            if success then
                ui.showMessage("Script imported successfully", "success")
            else
                ui.showMessage("Import failed: " .. result, "error")
            end
        end
        
    elseif choice == 2 then
        io.write(ui.colors.yellow .. "\nEnter local file path: " .. ui.colors.reset)
        local file_path = io.read():gsub("%s+", "")
        
        io.write(ui.colors.yellow .. "Enter script name: " .. ui.colors.reset)
        local script_name = io.read():gsub("%s+", "")
        
        if file_path and script_name then
            local content = M.readScript(file_path)
            if content then
                local success, result = M.saveScript("Custom", script_name, content, true)
                if success then
                    ui.showMessage("Script imported successfully", "success")
                else
                    ui.showMessage("Import failed: " .. result, "error")
                end
            else
                ui.showMessage("Failed to read file: " .. file_path, "error")
            end
        end
    end
end

-- Show templates menu
function M.showTemplatesMenu()
    ui.clearScreen()
    ui.printSeparator(54, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "✦ SCRIPT TEMPLATES ✦" .. ui.colors.reset)
    ui.printSeparator(54, "═", ui.colors.cyan)
    
    print(ui.colors.yellow .. "Available Templates:" .. ui.colors.reset)
    for i, template in ipairs(DEFAULT_SCRIPTS) do
        print(string.format("  [%d] %s", i, template.name))
        print("      " .. ui.colors.cyan .. template.description .. ui.colors.reset)
    end
    
    local choice = ui.getNumberInput("\nSelect template (1-" .. #DEFAULT_SCRIPTS .. "): ", 1, #DEFAULT_SCRIPTS)
    local template = DEFAULT_SCRIPTS[choice]
    
    -- Preview template
    print(ui.colors.yellow .. "\nTemplate Preview (first 500 chars):" .. ui.colors.reset)
    print(ui.colors.white .. template.content:sub(1, 500) .. ui.colors.reset)
    if #template.content > 500 then
        print(ui.colors.yellow .. "... " .. (#template.content - 500) .. " more characters" .. ui.colors.reset)
    end
    
    if ui.confirm("\nUse this template?", ui.colors.green) then
        M.createScriptWizardWithTemplate(template)
    end
end

-- Create script with template
function M.createScriptWizardWithTemplate(template)
    -- Similar to createScriptWizard but with template as starting point
    -- Implementation would be similar to createScriptWizard
    ui.showMessage("Template functionality coming soon!", "info")
end

-- Executor setup menu
function M.executorSetupMenu()
    ui.clearScreen()
    ui.printSeparator(54, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "✦ EXECUTOR SETUP ✦" .. ui.colors.reset)
    ui.printSeparator(54, "═", ui.colors.cyan)
    
    print(ui.colors.yellow .. "Detected Executors:" .. ui.colors.reset)
    local executors = M.getAvailableExecutors()
    
    if #executors == 0 then
        print(ui.colors.red .. "  No executors detected!" .. ui.colors.reset)
    else
        for _, executor in ipairs(executors) do
            local dir = M.getScriptDir(executor)
            print(string.format("  ✓ %-10s: %s", executor, dir))
        end
    end
    
    print()
    print(ui.colors.yellow .. "Setup Options:" .. ui.colors.reset)
    print("  [1] Create all script directories")
    print("  [2] Test executor detection")
    print("  [3] Add custom executor path")
    print("  [4] Back")
    
    local choice = ui.getNumberInput("\nSelect option (1-4): ", 1, 4)
    
    if choice == 1 then
        for _, executor in ipairs(SUPPORTED_EXECUTORS) do
            M.createScriptDir(executor)
        end
        ui.showMessage("All script directories created", "success")
        
    elseif choice == 2 then
        print(ui.colors.cyan .. "\nTesting executor detection..." .. ui.colors.reset)
        for _, executor in ipairs(SUPPORTED_EXECUTORS) do
            local installed = M.isExecutorInstalled(executor)
            local status = installed and ui.colors.green .. "✓" or ui.colors.red .. "✗"
            print(string.format("  %-10s: %s", executor, status .. ui.colors.reset))
        end
        
    elseif choice == 3 then
        io.write(ui.colors.yellow .. "\nEnter executor name: " .. ui.colors.reset)
        local name = io.read()
        
        io.write(ui.colors.yellow .. "Enter script directory path: " .. ui.colors.reset)
        local path = io.read()
        
        if name and path then
            SCRIPT_DIRS[name:upper()] = path
            ui.showMessage("Custom executor added: " .. name, "success")
        end
    end
end

-- Export script menu
function M.exportScriptMenu()
    ui.clearScreen()
    ui.printSeparator(54, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "✦ EXPORT SCRIPTS ✦" .. ui.colors.reset)
    ui.printSeparator(54, "═", ui.colors.cyan)
    
    -- Get scripts to export
    local executors = M.getAvailableExecutors()
    local all_scripts = {}
    
    for _, executor in ipairs(executors) do
        local scripts = M.listScripts(executor)
        for _, script in ipairs(scripts) do
            table.insert(all_scripts, script)
        end
    end
    
    if #all_scripts == 0 then
        ui.showMessage("No scripts found to export", "warning")
        return
    end
    
    print(ui.colors.yellow .. "Found " .. #all_scripts .. " scripts:" .. ui.colors.reset)
    for i, script in ipairs(all_scripts) do
        print(string.format("  [%d] %s (%s)", i, script.name, script.executor))
    end
    
    print()
    print(ui.colors.yellow .. "Export Options:" .. ui.colors.reset)
    print("  [1] Export all scripts")
    print("  [2] Select specific scripts")
    print("  [3] Export format: ZIP")
    print("  [4] Export format: JSON")
    print("  [5] Cancel")
    
    local choice = ui.getNumberInput("\nSelect option (1-5): ", 1, 5)
    
    if choice == 1 or choice == 2 then
        local scripts_to_export = {}
        
        if choice == 1 then
            scripts_to_export = all_scripts
        else
            io.write(ui.colors.yellow .. "\nEnter script numbers (e.g., 1,3,5): " .. ui.colors.reset)
            local input = io.read():gsub("%s+", "")
            
            for str in input:gmatch("[^,]+") do
                local idx = tonumber(str)
                if idx and idx >= 1 and idx <= #all_scripts then
                    table.insert(scripts_to_export, all_scripts[idx])
                end
            end
        end
        
        if #scripts_to_export == 0 then
            ui.showMessage("No scripts selected", "warning")
            return
        end
        
        local format_choice = ui.getNumberInput("\nExport format (3=ZIP, 4=JSON): ", 3, 4)
        local format = format_choice == 3 and "zip" or "json"
        
        local success, result = M.exportCollection(scripts_to_export, format)
        if success then
            ui.showMessage("Export successful: " .. result, "success")
        else
            ui.showMessage("Export failed: " .. result, "error")
        end
    end
end

-- Auto-inject divine monitor scripts
function M.autoInjectDivineMonitor(config_data)
    if not config_data.webhook.enabled then
        return false, "Webhook not enabled"
    end
    
    local results = {}
    
    for _, pkg in ipairs(config_data.packages) do
        local success, message = M.createDivineMonitorScript(config_data, pkg)
        table.insert(results, {
            package = pkg,
            success = success,
            message = message
        })
    end
    
    return results
end

-- Initialize script manager
function M.initialize()
    print(ui.colors.cyan .. "[*] Initializing script manager..." .. ui.colors.reset)
    
    -- Create custom directory if it doesn't exist
    M.createScriptDir("Custom")
    
    -- Check for available executors
    local executors = M.getAvailableExecutors()
    if #executors > 0 then
        print(ui.colors.green .. "[+] Found " .. #executors .. " executor(s)" .. ui.colors.reset)
    else
        print(ui.colors.yellow .. "[!] No executors found. Using Custom directory." .. ui.colors.reset)
    end
    
    return true
end

return M