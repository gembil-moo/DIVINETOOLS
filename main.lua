-- ===== WARNA ANSI =====
local iceblue = "\27[38;5;51m"
local green   = "\27[38;5;46m"
local red     = "\27[31m"
local yellow  = "\27[33m"
local reset   = "\27[0m"

-- Muat library CJSON untuk konfigurasi
local cjson = require "cjson"

local function border(width)
    width = width or 50
    print(red .. string.rep("═", width) .. reset)
end

local divine = {
"██████╗ ██╗██╗   ██╗██╗███╗   ██╗███████╗",
"██╔══██╗██║██║   ██║██║████╗  ██║██╔════╝",
"██║  ██║██║██║   ██║██║██╔██╗ ██║█████╗  ",
"██║  ██║██║╚██╗ ██╔╝██║██║╚██╗██║██╔══╝  ",
"██████╔╝██║ ╚████╔╝ ██║██║ ╚████║███████╗",
"╚═════╝ ╚═╝  ╚═══╝  ╚═╝╚═╝  ╚═══╝╚══════╝"
}

local function printBanner()
    for _, line in ipairs(divine) do
        print(iceblue .. line .. reset)
    end
end

-- ===== CONFIG HELPER (JSON FORMAT) =====
local CONFIG_PATH = "config.json"

local function loadConfig()
    local file = io.open(CONFIG_PATH, "r")
    local config = {}
    if file then
        local content = file:read("*a")
        file:close()
        local success, result = pcall(cjson.decode, content)
        if success then config = result end
    end

    -- Set default values if they don't exist
    if not config.packages then config.packages = {} end
    if not config.private_servers then
        config.private_servers = { mode = "same", url = "", urls = {} }
    end
    if not config.webhook then
        config.webhook = { enabled = false, url = "", mode = "new", interval = 5, tag_everyone = false }
    end
    if not config.delay_launch then config.delay_launch = 0 end
    if not config.delay_relaunch then config.delay_relaunch = 0 end
    if config.mask_username == nil then config.mask_username = false end
    return config
end

local function saveConfig(config)
    local file = io.open(CONFIG_PATH, "w")
    if file then
        -- Gunakan cjson untuk menyimpan dengan format yang rapi
        file:write(cjson.encode(config))
        file:close()
    else
        print(red.."Error: Could not save config."..reset)
    end
end

local function getUsername(pkg)
    -- Redirect stderr ke /dev/null agar error tidak muncul di layar
    local handle = io.popen("su -c 'cat /data/data/" .. pkg .. "/shared_prefs/prefs.xml 2>/dev/null' 2>/dev/null")
    if not handle then return nil end
    local content = handle:read("*a")
    handle:close()
    
    local user = content and content:match('name="username">([^<]+)<') or nil
    return user
end

local function maskString(str)
    if not str or #str <= 4 then return str end
    return str:sub(1, 3) .. "xxx" .. str:sub(-2)
end

-- ===== EXECUTOR HELPER =====
local function getExecutorFolders()
    local targets = {}
    local delta_dir = "/storage/emulated/0/Delta/Autoexecute"
    local fluxus_dir = "/storage/emulated/0/FluxusZ/autoexec"
    
    local function exists(path)
        local h = io.popen("ls -d " .. path .. " 2>/dev/null")
        local res = h:read("*a")
        h:close()
        return res and res ~= ""
    end

    if exists("/storage/emulated/0/Delta") then table.insert(targets, delta_dir) end
    if exists("/storage/emulated/0/FluxusZ") then table.insert(targets, fluxus_dir) end
    if #targets == 0 then table.insert(targets, delta_dir) end -- Default to Delta
    
    return targets
end

local function installDivineMonitor(config)
    local targets = getExecutorFolders()
    for _, dir in ipairs(targets) do
        os.execute("mkdir -p " .. dir)
        
        local cfg_content = "-- Divine Monitor Config\n"
        cfg_content = cfg_content .. 'getgenv().DVN_WEBHOOK_URL = "' .. (config.webhook.url or "") .. '"\n'
        cfg_content = cfg_content .. 'getgenv().DVN_MENTION_EVERYONE = ' .. tostring(config.webhook.tag_everyone or false) .. '\n'
        
        local f_cfg = io.open(dir .. "/00_DivineConfig.txt", "w")
        if f_cfg then f_cfg:write(cfg_content) f_cfg:close() end

        local loader_content = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/gembil-moo/DIVINETOOLS/refs/heads/main/Divine.lua"))()'
        local f_load = io.open(dir .. "/01_DivineMonitor.txt", "w")
        if f_load then f_load:write(loader_content) f_load:close() end
    end
end

local function CalculateBounds(index, total_pkg, screenW, screenH)
    -- === CONFIGURASI GRID PINTAR ===
    local cols, rows
    local y_offset = 0 -- Jarak aman dari atas (buat Termux/Status)

    if total_pkg == 1 then
        -- KASUS 1 AKUN (CINEMA MODE)
        local margin_top = math.floor(screenH * 0.15) 
        local margin_bot = math.floor(screenH * 0.05) 
        return string.format("0,%d,%d,%d", margin_top, screenW, screenH - margin_bot)

    elseif total_pkg == 2 then
        -- KASUS 2 AKUN (DUAL STACK)
        cols = 1
        rows = 2
        y_offset = 120 

    elseif total_pkg <= 8 then
        -- KASUS 3-8 AKUN (GRID 2 KOLOM)
        cols = 2
        rows = math.ceil(total_pkg / 2)
        if rows < 2 then rows = 2 end
        y_offset = 80 

    else 
        -- KASUS 9+ AKUN (GRID 3 KOLOM)
        cols = 3
        rows = math.ceil(total_pkg / 3)
        y_offset = 60 
    end

    -- === RUMUS MATEMATIKA GRID ===
    local usable_H = screenH - y_offset
    local w = math.floor(screenW / cols)
    local h = math.floor(usable_H / rows)
    
    local i = index - 1 
    local c = i % cols
    local r = math.floor(i / cols)

    local x1 = c * w
    local y1 = y_offset + (r * h)
    local x2 = x1 + w
    local y2 = y1 + h

    return string.format("%d,%d,%d,%d", x1, y1, x2, y2)
end

-- ===== SUB MENU CONFIG (UPDATED) =====
local function configMenu()
    while true do
        os.execute("clear")
        border()
        print("        "..green.."✦ EDIT CONFIGURATION ✦"..reset)
        border()

        print("  [1] APK Package List")
        print("  [2] Private Server List")
        print("  [3] Script")
        print("  [4] Webhook")
        print("  [5] Delay Launch")
        print("  [6] Delay Relaunch Loop")
        print("  [7] Mask Username Toggle")
        print("  [8] Back to Main Menu")

        border()
        io.write(yellow.."Select option (1-8): "..reset)
        local c = io.read()

        os.execute("clear")

        if c == "1" then
            border()
            print("        "..green.."✦ APK PACKAGE LIST ✦"..reset)
            border()
            print("  [1] Show List")
            print("  [2] Edit List")
            print("  [3] Back")
            border()
            io.write(yellow.."Select option (1-3): "..reset)
            local sub_c = io.read()

            os.execute("clear")

            if sub_c == "1" then
                print(green.."Showing APK Package List..."..reset)
                local cfg = loadConfig()
                border()
                if #cfg.packages == 0 then
                    print(red.."  No packages saved."..reset)
                else
                    for i, pkg in ipairs(cfg.packages) do
                        local user = getUsername(pkg)
                        local display_user = (user and cfg.mask_username) and maskString(user) or user
                        local status = user and (green .. " (" .. display_user .. ")" .. reset) or (red .. " (Not Logged In)" .. reset)
                        print("  ["..i.."] " .. pkg .. status)
                    end
                end
                border()
                print("\nPress ENTER to return...")
                io.read()

            elseif sub_c == "2" then
                border()
                print("        "..green.."✦ EDIT APK LIST ✦"..reset)
                border()
                print("  [1] Add Package")
                print("  [2] Remove Package")
                border()
                io.write(yellow.."Select option (1-2): "..reset)
                local edit_c = io.read()

                os.execute("clear")

                if edit_c == "1" then
                    print(green.."Scanning for com.roblox.* packages..."..reset)
                    local handle = io.popen("pm list packages | grep com.roblox")
                    local result = handle:read("*a")
                    handle:close()

                    local scanned_packages = {}
                    for line in result:gmatch("[^\r\n]+") do
                        local pkg = line:match("package:(.*)")
                        if pkg then
                            table.insert(scanned_packages, pkg)
                        end
                    end

                    if #scanned_packages > 0 then
                        border()
                        for i, pkg in ipairs(scanned_packages) do
                            print("  ["..i.."] " .. pkg)
                        end
                        border()
                        io.write(yellow.."Select package(s) (e.g. 1,3,4 or ENTER for all): "..reset)
                        local input = io.read()
                        if input then input = input:gsub("%s+", "") end
                        
                        local selected_indices = {}
                        if not input or input == "" then
                            for i = 1, #scanned_packages do table.insert(selected_indices, i) end
                        else
                            for str in string.gmatch(input, "([^,]+)") do
                                local n = tonumber(str)
                                if n and scanned_packages[n] then table.insert(selected_indices, n) end
                            end
                        end

                        if #selected_indices > 0 then
                            local config = loadConfig()
                            if not config.packages then config.packages = {} end
                            local exists = {}
                            for _, p in ipairs(config.packages) do exists[p] = true end
                            
                            local packages_added = {}
                            for _, idx in ipairs(selected_indices) do
                                local pkg_name = scanned_packages[idx]
                                if not exists[pkg_name] then
                                    table.insert(config.packages, pkg_name)
                                    table.insert(packages_added, pkg_name)
                                    -- Tandai sudah ada untuk mencegah duplikasi dari input yang sama (misal: 1,1)
                                    exists[pkg_name] = true
                                end
                            end

                            if #packages_added > 0 then
                                saveConfig(config)
                                print(green.."Saved "..#packages_added.." new package(s) to config/config.lua!"..reset)
                            else
                                print(yellow.."No new packages were added. They may already exist in the config."..reset)
                            end
                        else
                            print(red.."Invalid selection!"..reset)
                        end
                    else
                        print(red.."No com.roblox packages found."..reset)
                    end
                elseif edit_c == "2" then
                    border()
                    print("        "..green.."✦ REMOVE PACKAGE ✦"..reset)
                    border()
                    
                    local config = loadConfig()
                    if #config.packages == 0 then
                        print(red.."  No packages saved."..reset)
                    else
                        for i, pkg in ipairs(config.packages) do
                            print("  ["..i.."] " .. pkg)
                        end
                        border()
                        io.write(yellow.."Select package index to remove: "..reset)
                        local idx = tonumber(io.read())
                        if idx and config.packages[idx] then
                            table.remove(config.packages, idx)
                            saveConfig(config)
                            print(green.."Package removed successfully!"..reset)
                        else
                            print(red.."Invalid selection!"..reset)
                        end
                    end
                end
            elseif sub_c == "3" then
                -- Back to Config Menu
            else
                print(red.."Invalid option!"..reset)
            end

        elseif c == "2" then
            os.execute("clear")
            border()
            print("        "..green.."✦ PRIVATE SERVER LIST ✦"..reset)
            border()

            local config = loadConfig()

            -- Tampilkan pengaturan saat ini
            print(yellow.."Current Mode: "..reset .. (config.private_servers.mode or "not set"))
            if config.private_servers.mode == "same" then
                print(yellow.."URL: "..reset .. (config.private_servers.url or "not set"))
            elseif config.private_servers.mode == "per_package" then
                print(yellow.."URLs per Package:"..reset)
                if config.private_servers.urls and next(config.private_servers.urls) then
                     for pkg, url in pairs(config.private_servers.urls) do
                        print("  - " .. pkg .. ": " .. url)
                     end
                else
                    print("  (No URLs set)")
                end
            end
            border()

            io.write(yellow.."Use the same link for all packages? (y/n): "..reset)
            local choice = io.read()

            if choice:lower() == 'y' then
                io.write(yellow.."Enter the single private server URL: "..reset)
                local url = io.read()
                config.private_servers.mode = "same"
                config.private_servers.url = url
                config.private_servers.urls = {} -- Hapus data mode lain
                saveConfig(config)
                print(green.."\nSaved single URL configuration!"..reset)
            elseif choice:lower() == 'n' then
                if #config.packages == 0 then
                    print(red.."\nNo packages found. Please add packages first in menu [1]."..reset)
                else
                    config.private_servers.mode = "per_package"
                    config.private_servers.url = "" -- Hapus data mode lain
                    print(yellow.."\nEnter the URL for each package (press ENTER to keep current):"..reset)
                    for _, pkg in ipairs(config.packages) do
                        local current_url = config.private_servers.urls[pkg] or ""
                        io.write("  - " .. pkg .. " ["..current_url.."]: "..reset)
                        local new_url = io.read()
                        if new_url and new_url ~= "" then config.private_servers.urls[pkg] = new_url end
                    end
                    saveConfig(config)
                    print(green.."\nSaved per-package URL configuration!"..reset)
                end
            else
                print(red.."\nInvalid choice. No changes made."..reset)
            end
        elseif c == "3" then
            print(green.."Opening Script Manager..."..reset)

        elseif c == "4" then
            border()
            print("        "..green.."✦ WEBHOOK CONFIGURATION ✦"..reset)
            border()

            local config = loadConfig()
            
            -- Display current config
            print(yellow.."Current Status: "..reset .. (config.webhook.enabled and (green.."Enabled"..reset) or (red.."Disabled"..reset)))
            if config.webhook.enabled then
                print(yellow.."URL: "..reset .. (config.webhook.url ~= "" and config.webhook.url:sub(1, 40).."..." or "Not Set"))
                print(yellow.."Mode: "..reset .. (config.webhook.mode == "edit" and "Edit Message" or "New Message"))
                print(yellow.."Interval: "..reset .. config.webhook.interval .. " minutes")
                print(yellow.."Tag Everyone: "..reset .. (config.webhook.tag_everyone and "Yes" or "No"))
            end
            border()

            io.write(yellow.."Enable Webhook? (y/n): "..reset)
            local enable_input = io.read():lower()

            if enable_input == "n" then
                config.webhook.enabled = false
                saveConfig(config)
                print(red.."\nWebhook disabled."..reset)
            elseif enable_input == "y" then
                config.webhook.enabled = true
                
                io.write(yellow.."Enter Webhook URL: "..reset)
                local url = io.read()
                if url and url ~= "" then config.webhook.url = url end

                print(yellow.."\nSelect Mode:"..reset)
                print("  [1] Send New Message")
                print("  [2] Edit Existing Message")
                io.write(yellow.."Choose (1-2): "..reset)
                local mode_sel = io.read()
                config.webhook.mode = (mode_sel == "2") and "edit" or "new"

                while true do
                    io.write(yellow.."\nUpdate Interval (min 5 mins): "..reset)
                    local interval = tonumber(io.read())
                    if interval and interval >= 5 then
                        config.webhook.interval = interval
                        break
                    else
                        print(red.."Interval must be at least 5 minutes!"..reset)
                    end
                end

                io.write(yellow.."\nTag @everyone? (y/n): "..reset)
                local tag = io.read():lower()
                config.webhook.tag_everyone = (tag == "y")

                saveConfig(config)
                installDivineMonitor(config) -- Update script config when webhook changes
                print(green.."\nWebhook configuration saved!"..reset)
            else
                print(red.."\nInvalid option. No changes made."..reset)
            end

        elseif c == "5" then
            border()
            print("        "..green.."✦ DELAY LAUNCH CONFIG ✦"..reset)
            border()
            local config = loadConfig()
            print(yellow.."Current Delay: "..reset .. (config.delay_launch > 0 and (config.delay_launch.." seconds") or "Off (0s)"))
            border()
            
            io.write(yellow.."Enter delay in seconds (ENTER for 0/Off): "..reset)
            local input = io.read()
            local delay = tonumber(input) or 0
            
            config.delay_launch = delay
            saveConfig(config)
            print(green.."\nDelay Launch set to "..delay.." seconds."..reset)

        elseif c == "6" then
            border()
            print("        "..green.."✦ RELAUNCH LOOP CONFIG ✦"..reset)
            border()
            local config = loadConfig()
            print(yellow.."Current Delay: "..reset .. (config.delay_relaunch > 0 and (config.delay_relaunch.." minutes") or "Off (0m)"))
            border()
            
            io.write(yellow.."Enter delay in minutes (ENTER for 0/Off): "..reset)
            local input = io.read()
            local delay = tonumber(input) or 0
            
            config.delay_relaunch = delay
            saveConfig(config)
            print(green.."\nRelaunch Loop Delay set to "..delay.." minutes."..reset)

        elseif c == "7" then
            border()
            print("        "..green.."✦ MASK USERNAME CONFIG ✦"..reset)
            border()
            local config = loadConfig()
            print(yellow.."Current Status: "..reset .. (config.mask_username and (green.."Enabled"..reset) or (red.."Disabled"..reset)))
            border()
            
            io.write(yellow.."Enable username masking? (y/n): "..reset)
            local choice = io.read():lower()
            
            if choice == "y" then
                config.mask_username = true
                saveConfig(config)
                print(green.."\nUsername masking enabled."..reset)
            elseif choice == "n" then
                config.mask_username = false
                saveConfig(config)
                print(red.."\nUsername masking disabled."..reset)
            else
                print(red.."\nInvalid option. No changes made."..reset)
            end

        elseif c == "8" then
            break

        else
            print(red.."Invalid option!"..reset)
        end

        if c ~= "1" then -- Pause for non-submenu items
            print("\nPress ENTER to return...")
            io.read()
        end
    end
end


-- ===== MAIN MENU =====
local function showMain()
    border()
    printBanner()
    print("        " .. green .. "✦ VERSI APLIKASI ✦" .. reset)
    border()

    print(red.."║"..reset.."  [1] Start")
    print(red.."║"..reset.."  [2] First Configuration")
    print(red.."║"..reset.."  [3] Edit Configuration")
    print(red.."║"..reset.."  [4] Optimize Device")
    print(red.."║"..reset.."  [5] Uninstall")
    print(red.."║"..reset.."  [6] Exit")

    border()
end

-- ===== LOOP UTAMA =====
while true do
    os.execute("clear")
    showMain()

    io.write(yellow.."\nSelect menu (1-6): "..reset)
    local pilih = io.read()

    os.execute("clear")

    if pilih == "1" then
        print(green.."Starting application..."..reset)

    elseif pilih == "2" then
        border()
        print("        "..green.."✦ FIRST CONFIGURATION ✦"..reset)
        border()

        local config = loadConfig()

        local proceed = true
        if #config.packages > 0 then
            print(yellow.."Existing configuration found ("..#config.packages.." packages)."..reset)
            io.write(red.."Overwrite? (y/n): "..reset)
            if io.read():lower() ~= "y" then
                proceed = false
                print(red.."\nCancelled."..reset)
            end
        end

        if proceed then
            -- 1. Auto Detect Packages
            print(green.."[*] Scanning for com.roblox packages..."..reset)
            local handle = io.popen("pm list packages | grep com.roblox")
            local result = handle:read("*a")
            handle:close()

            local scanned = {}
            for line in result:gmatch("[^\r\n]+") do
                local p = line:match("package:(.*)")
                if p then table.insert(scanned, p) end
            end

            if #scanned == 0 then
                print(red.."No packages found! Install Roblox first."..reset)
            else
                print(yellow.."Found "..#scanned.." packages:"..reset)
                for i, p in ipairs(scanned) do print("  ["..i.."] "..p) end
                
                io.write(yellow.."\nPress ENTER to select all (or type indices e.g. 1,2): "..reset)
                local sel = io.read()
                config.packages = {}
                if sel == "" then
                    for _, p in ipairs(scanned) do table.insert(config.packages, p) end
                else
                    for str in string.gmatch(sel, "([^,]+)") do
                        local n = tonumber(str)
                        if n and scanned[n] then table.insert(config.packages, scanned[n]) end
                    end
                end
                print(green.."Selected "..#config.packages.." packages."..reset)
            end

            if #config.packages > 0 then
                -- 2. Private Server
                border()
                io.write(yellow.."Use same private server URL for all packages? (y/n): "..reset)
                local same_ps = io.read():lower()
                
                if same_ps == "n" then
                    config.private_servers.mode = "per_package"
                    config.private_servers.url = ""
                    config.private_servers.urls = {}
                    print(yellow.."Enter URL for each package:"..reset)
                    for _, pkg in ipairs(config.packages) do
                        io.write("  "..pkg..": ")
                        local u = io.read()
                        config.private_servers.urls[pkg] = u
                    end
                else
                    config.private_servers.mode = "same"
                    io.write(yellow.."Enter Private Server URL: "..reset)
                    config.private_servers.url = io.read()
                    config.private_servers.urls = {}
                end

                -- 3. Mask Username
                border()
                io.write(yellow.."Mask username in status table (e.g. DIVxxxNE)? (y/n): "..reset)
                config.mask_username = (io.read():lower() == "y")

                -- 4. Delay Launch
                border()
                io.write(yellow.."Delay Launch (seconds) [ENTER=0]: "..reset)
                config.delay_launch = tonumber(io.read()) or 0

                -- 5. Webhook
                border()
                io.write(yellow.."Webhook URL (Critical Alerts) [ENTER to skip]: "..reset)
                local wh_url = io.read()
                
                if wh_url and wh_url ~= "" then
                    config.webhook.enabled = true
                    config.webhook.url = wh_url
                    
                    print(yellow.."Webhook Mode:"..reset)
                    print("  [1] Send New Message (Default)")
                    print("  [2] Edit Previous Message")
                    print("  [3] Disable Status Updates")
                    io.write(yellow.."Select (1-3): "..reset)
                    local wh_mode = io.read()
                    if wh_mode == "2" then config.webhook.mode = "edit"
                    elseif wh_mode == "3" then config.webhook.mode = "disabled_status"
                    else config.webhook.mode = "new" end
                    
                    io.write(yellow.."Tag @everyone? (y/n): "..reset)
                    config.webhook.tag_everyone = (io.read():lower() == "y")
                    
                    io.write(yellow.."Status Update Interval (min 5 mins, 0/Enter = Off): "..reset)
                    local wh_int = tonumber(io.read()) or 0
                    if wh_int > 0 and wh_int < 5 then wh_int = 5 end
                    config.webhook.interval = wh_int
                else
                    config.webhook.enabled = false
                end

                -- 6. Relaunch Loop
                border()
                io.write(yellow.."Relaunch Loop Delay (minutes) [ENTER=0]: "..reset)
                config.delay_relaunch = tonumber(io.read()) or 0

                -- 7. Auto Execute Script Injection
                border()
                io.write(yellow.."Inject auto exe script? (y/n): "..reset)
                if io.read():lower() == "y" then
                    local script_num = 1
                    while true do
                        io.write(yellow.."\nInject script "..script_num.."? (y/n): "..reset)
                        if io.read():lower() ~= "y" then break end

                        print(green.."Enter script content (loadstring etc).")
                        print(yellow.."Type 'END' on a new line to finish:"..reset)
                        
                        local lines = {}
                        while true do
                            local line = io.read()
                            if line == "END" then break end
                            table.insert(lines, line)
                        end
                        local content = table.concat(lines, "\n")

                        -- Detect Executor Folders
                        local targets = getExecutorFolders()
                        for _, dir in ipairs(targets) do
                            os.execute("mkdir -p " .. dir)
                            local f = io.open(dir .. "/script_" .. script_num .. ".txt", "w")
                            if f then f:write(content) f:close() end
                        end
                        print(green.."Script saved to auto-execute folder(s)."..reset)
                        script_num = script_num + 1
                    end
                end

                -- 8. Install Divine Monitor (Mandatory)
                print(green.."\n[*] Installing Divine Monitor (Mandatory)..."..reset)
                installDivineMonitor(config)

                -- Save
                saveConfig(config)
                print(green.."\nConfiguration saved successfully!"..reset)
            end
        end

    elseif pilih == "3" then
        configMenu()

    elseif pilih == "4" then
        print(green.."Optimizing device..."..reset)

    elseif pilih == "5" then
        print(red.."Uninstalling components..."..reset)

    elseif pilih == "6" then
        print(iceblue.."Exiting... Goodbye!"..reset)
        break

    else
        print(red.."Invalid selection!"..reset)
    end

    print("\nPress ENTER to return to main menu...")
    io.read()
end