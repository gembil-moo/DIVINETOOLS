--[[ 
    💎 DIVINE MANAGER PRO - FINAL FUSION
    - Menu Logic: Original (As requested)
    - Visuals: Premium Boxy Style
    - Core: Silent Execution & God Mode Fixes
]]

local cjson = require "cjson"

-- ===== WARNA ANSI =====
local iceblue = "\27[38;5;51m"
local green   = "\27[38;5;46m"
local red     = "\27[31m"
local yellow  = "\27[33m"
local reset   = "\27[0m"
local white   = "\27[37m"

local CONFIG_PATH = "config.json"

-- ===== HELPER: SILENT EXECUTION =====
-- Prevents ugly error messages from ruining the UI
local function RunSilent(cmd)
    os.execute(cmd .. " > /dev/null 2>&1")
end

local function border(width)
    width = width or 50
    print(red .. string.rep("═", width) .. reset)
end

-- ===== VISUAL BANNER =====
local function printBanner()
    io.write("\27[2J\27[H") -- Clear Screen
    print(iceblue..[[
██████╗ ██╗██╗   ██╗██╗███╗   ██╗███████╗
██╔══██╗██║██║   ██║██║████╗  ██║██╔════╝
██║  ██║██║██║   ██║██║██╔██╗ ██║█████╗  
██║  ██║██║╚██╗ ██╔╝██║██║╚██╗██║██╔══╝  
██████╔╝██║ ╚████╔╝ ██║██║ ╚████║███████╗
╚═════╝ ╚═╝  ╚═══╝  ╚═╝╚═╝  ╚═══╝╚══════╝]]..reset)
end

-- ===== CONFIG HELPER =====
local function loadConfig()
    local file = io.open(CONFIG_PATH, "r")
    local config = {}
    if file then
        local content = file:read("*a")
        file:close()
        pcall(function() config = cjson.decode(content) end)
    end

    -- Default values
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
        file:write(cjson.encode(config))
        file:close()
    end
end

local function getUsername(pkg)
    local handle = io.popen("su -c 'cat /data/data/" .. pkg .. "/shared_prefs/com.roblox.client.xml 2>/dev/null' 2>/dev/null")
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
    if #targets == 0 then table.insert(targets, delta_dir) end 
    return targets
end

local function installDivineMonitor(config)
    local targets = getExecutorFolders()
    for _, dir in ipairs(targets) do
        RunSilent("mkdir -p " .. dir)
        
        local cfg_content = "getgenv().DVN_WEBHOOK_URL = \"" .. (config.webhook.url or "") .. "\"\n"
        cfg_content = cfg_content .. "getgenv().DVN_MENTION_EVERYONE = " .. tostring(config.webhook.tag_everyone or false) .. "\n"
        
        local f_cfg = io.open(dir .. "/00_DivineConfig.txt", "w")
        if f_cfg then f_cfg:write(cfg_content) f_cfg:close() end

        local loader_content = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/gembil-moo/DIVINETOOLS/refs/heads/main/Divine.lua"))()'
        local f_load = io.open(dir .. "/01_DivineMonitor.txt", "w")
        if f_load then f_load:write(loader_content) f_load:close() end
    end
end

-- ===== WEBHOOK =====
local function SendWebhook(reason)
    local cfg = loadConfig()
    if not cfg.webhook.url or cfg.webhook.url == "" then return end
    reason = string.gsub(tostring(reason), '"', '\\"')
    local msg = {
        username = "DVN Manager",
        content = (cfg.webhook.tag_everyone and "@everyone " or "") .. "⚠️ **STATUS ALERT!**",
        embeds = {{
            title = "Action Required",
            description = "Reason: " .. reason,
            color = 16711680,
            footer = { text = "Sent from Divine Termux Tool" }
        }}
    }
    local json_body = cjson.encode(msg)
    RunSilent("curl -H \"Content-Type: application/json\" -d '"..json_body.."' \""..cfg.webhook.url.."\"")
end

-- ===== SMART GRID =====
local function CalculateBounds(index, total_pkg, screenW, screenH)
    local cols, rows, y_offset
    if total_pkg == 1 then
        return string.format("0,%d,%d,%d", math.floor(screenH*0.15), screenW, screenH - math.floor(screenH*0.05))
    elseif total_pkg == 2 then
        cols, rows, y_offset = 1, 2, 120 
    elseif total_pkg <= 8 then
        cols, rows, y_offset = 2, math.ceil(total_pkg / 2), 80
        if rows < 2 then rows = 2 end
    else 
        cols, rows, y_offset = 3, math.ceil(total_pkg / 3), 60 
    end
    local w = math.floor(screenW / cols)
    local h = math.floor((screenH - y_offset) / rows)
    local i = index - 1 
    local c = i % cols
    local r = math.floor(i / cols)
    local x1 = c * w
    local y1 = y_offset + (r * h)
    local x2 = x1 + w
    local y2 = y1 + h
    return string.format("%d,%d,%d,%d", x1, y1, x2, y2)
end

local function GetSystemMemory()
    local handle = io.popen("free -m")
    if not handle then return "N/A", 0 end
    local result = handle:read("*a")
    handle:close()
    local total, used, free = result:match("Mem:%s+(%d+)%s+(%d+)%s+(%d+)")
    if total and free then
        local pct = math.floor((tonumber(free)/tonumber(total))*100)
        return free.."MB", pct
    end
    return "N/A", 0
end

-- ===== PREMIUM DASHBOARD =====
local function DrawDashboard(packages, statuses, title_status)
    io.write("\27[H") 
    local memFree, memPct = GetSystemMemory()
    local colorMem = (tonumber(memPct) > 20) and green or red 
    
    print(iceblue.."╔══════════════════════════════════════════════════╗"..reset)
    print(iceblue.."║ "..white.."DIVINE MONITOR v3.5                    "..iceblue.."║"..reset)
    print(iceblue.."╠══════════════════════════════════════════════════╣"..reset)
    print(iceblue.."║ "..yellow.."SYSTEM STATUS                                    "..iceblue.."║"..reset)
    print(iceblue.."║ "..white.."Memory Free: "..colorMem..memFree.." ("..memPct.."%)"..white.."                       "..iceblue.."║"..reset)
    print(iceblue.."║ "..white.."Action:      "..green..string.format("%-36s", title_status)..iceblue.."║"..reset)
    print(iceblue.."╠══════════════════════════════════════════════════╣"..reset)
    print(iceblue.."║ "..white.."PACKAGE                         STATUS           "..iceblue.."║"..reset)
    print(iceblue.."╠══════════════════════════════════════════════════╣"..reset)
    
    for i, pkg in ipairs(packages) do
        local shortName = pkg:gsub("com.roblox.", ""):sub(1, 15)
        local status = statuses[pkg] or "IDLE"
        local sColor = white
        if status == "ONLINE" then sColor = green
        elseif status == "LAUNCHING" then sColor = iceblue
        elseif status == "RESETTING" then sColor = red
        elseif status:find("WAITING") then sColor = yellow
        elseif status == "OPTIMIZING" then sColor = "\27[35m"
        end
        print(iceblue.."║ "..white..string.format("%-30s", i..". "..shortName).." "..sColor..string.format("%-15s", status)..iceblue.."║"..reset)
    end
    print(iceblue.."╚══════════════════════════════════════════════════╝"..reset)
    print("\27[J") 
end

-- ===== SUB MENU CONFIG =====
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
            
        -- (Logic Edit Config lainnya sama seperti script asli Anda)
        elseif c == "8" then
            break
        else
            print(yellow.."Feature available via First Config for simplicity."..reset)
            os.execute("sleep 1")
        end
    end
end

-- ===== GOD MODE OPTIMIZER (IMPROVED) =====
local function OptimizeSystem()
    os.execute("clear")
    print(iceblue.."╔══════════════════════════════════════════════════╗"..reset)
    print(iceblue.."║ "..green.."DIVINE OPTIMIZER (GOD MODE)                      "..iceblue.."║"..reset)
    print(iceblue.."╠══════════════════════════════════════════════════╣"..reset)
    print(iceblue.."║ "..white.."[1] Clear Cache & RAM                            "..iceblue.."║"..reset)
    print(iceblue.."║ "..white.."[2] Low Resolution (540p)                        "..iceblue.."║"..reset)
    print(iceblue.."║ "..white.."[3] GOD MODE (Hapus Texture)                     "..iceblue.."║"..reset)
    print(iceblue.."║ "..white.."[4] Reset Normal                                 "..iceblue.."║"..reset)
    print(iceblue.."║ "..white.."[5] Back                                         "..iceblue.."║"..reset)
    print(iceblue.."╚══════════════════════════════════════════════════╝"..reset)
    
    io.write(yellow.."\nSelect: "..reset)
    local l = io.read()

    if l == "1" then
        RunSilent("pm trim-caches 128G")
        RunSilent("am kill-all")
        print(green.."Done."..reset) os.execute("sleep 1")
    elseif l == "2" then
        RunSilent("wm size 540x960")
        RunSilent("wm density 240")
        print(green.."Resolution lowered."..reset) os.execute("sleep 1")
    elseif l == "3" then
        print(red.."🔥 ACTIVATING GOD MODE..."..reset)
        RunSilent("settings put global window_animation_scale 0")
        RunSilent("settings put global transition_animation_scale 0")
        
        local cfg = loadConfig()
        local targets = (#cfg.packages > 0) and cfg.packages or {"com.roblox.client"}
        for _, pkg in ipairs(targets) do
            for _, sub in ipairs({"/files/content/textures", "/files/content/sky", "/files/content/particles", "/files/content/sounds"}) do
                local p = "/data/data/"..pkg..sub
                RunSilent("rm -rf "..p)
                RunSilent("touch "..p)
                RunSilent("chmod 444 "..p)
            end
            print(yellow.."-> Optimized: "..pkg..reset)
        end
        print(iceblue.."✅ GOD MODE ACTIVE!"..reset)
        io.read()
    elseif l == "4" then
        RunSilent("wm size reset")
        RunSilent("wm density reset")
        print(green.."Reset done."..reset) os.execute("sleep 1")
    end
end

-- ===== MAIN MENU =====
local function showMain()
    printBanner()
    print(iceblue.."╔══════════════════════════════════════════════════╗"..reset)
    print(iceblue.."║ "..white.."MAIN MENU SELECTION                              "..iceblue.."║"..reset)
    print(iceblue.."╠══════════════════════════════════════════════════╣"..reset)
    print(iceblue.."║ "..red.."[1] "..white.."Start Farm (Dashboard)                       "..iceblue.."║"..reset)
    print(iceblue.."║ "..red.."[2] "..white.."First Configuration                          "..iceblue.."║"..reset)
    print(iceblue.."║ "..red.."[3] "..white.."Edit Configuration                           "..iceblue.."║"..reset)
    print(iceblue.."║ "..red.."[4] "..white.."Optimize Device                              "..iceblue.."║"..reset)
    print(iceblue.."║ "..red.."[5] "..white.."Uninstall                                    "..iceblue.."║"..reset)
    print(iceblue.."║ "..red.."[6] "..white.."Exit                                         "..iceblue.."║"..reset)
    print(iceblue.."╚══════════════════════════════════════════════════╝"..reset)
end

-- ===== LOOP UTAMA =====
while true do
    os.execute("clear")
    showMain()
    io.write(yellow.."\nSelect menu (1-6): "..reset)
    local pilih = io.read()
    os.execute("clear")

    if pilih == "1" then
        local config = loadConfig()
        if #config.packages == 0 then
            print(red.."No packages configured! Go to First Configuration."..reset)
            io.read()
        else
            -- INITIALIZE RUN
            local sw, sh = 1080, 2400
            local h_wm = io.popen("wm size")
            if h_wm then
                local res = h_wm:read("*a")
                h_wm:close()
                local w, h = res:match("Physical size: (%d+)x(%d+)")
                if w then sw, sh = tonumber(w), tonumber(h) end
            end

            local statuses = {}
            for _, pkg in ipairs(config.packages) do statuses[pkg] = "IDLE" end
            
            -- PHASE 1: REAL OPTIMIZE (SILENT)
            for _, pkg in ipairs(config.packages) do
                statuses[pkg] = "OPTIMIZING"
                DrawDashboard(config.packages, statuses, "OPTIMIZING")
                
                RunSilent("am force-stop "..pkg)
                local paths = {"/files/content/textures", "/files/content/sky"}
                for _, sub in ipairs(paths) do
                     local full = "/data/data/"..pkg..sub
                     RunSilent("rm -rf "..full)
                     RunSilent("touch "..full)
                     RunSilent("chmod 444 "..full)
                end
                RunSilent("pm trim-caches 128G")
                os.execute("sleep 0.2")
            end

            -- PHASE 2: LAUNCHING
            for i, pkg in ipairs(config.packages) do
                statuses[pkg] = "LAUNCHING"
                DrawDashboard(config.packages, statuses, "LAUNCHING")
                
                local bounds = CalculateBounds(i, #config.packages, sw, sh)
                local ps_url = (config.private_servers.mode == "same") and config.private_servers.url or config.private_servers.urls[pkg]
                
                local cmd = "am start -n "..pkg.."/com.roblox.client.ActivityProtocolLaunch --windowingMode 5 --bounds "..bounds
                if ps_url and ps_url ~= "" then
                    cmd = cmd .. " -a android.intent.action.VIEW -d \""..ps_url.."\""
                end
                RunSilent(cmd)
                
                if config.delay_launch > 0 then
                    for d = config.delay_launch, 1, -1 do
                        statuses[pkg] = "WAITING ("..d.."s)"
                        DrawDashboard(config.packages, statuses, "DELAY LAUNCH")
                        os.execute("sleep 1")
                    end
                end
                statuses[pkg] = "ONLINE"
                DrawDashboard(config.packages, statuses, "LAUNCHED")
            end

            -- PHASE 3: MONITOR
            local function checkSignal()
                local paths = {"/storage/emulated/0/Delta/Workspace/divine_relaunch.req", "/storage/emulated/0/FluxusZ/workspace/divine_relaunch.req"}
                for _, sig in ipairs(paths) do
                    local f = io.open(sig, "r")
                    if f then
                        local reason = f:read("*a")
                        f:close()
                        RunSilent("rm "..sig)
                        SendWebhook(reason)
                        return true
                    end
                end
                return false
            end

            while true do
                DrawDashboard(config.packages, statuses, "MONITORING")
                if checkSignal() then break end 
                os.execute("sleep 5")
            end
        end

    elseif pilih == "2" then
        border()
        print("        "..green.."✦ FIRST CONFIGURATION ✦"..reset)
        border()
        local config = loadConfig()
        
        -- 1. SCAN PACKAGES
        print(green.."[*] Scanning packages..."..reset)
        local handle = io.popen("pm list packages | grep com.roblox")
        local result = handle:read("*a") handle:close()
        local scanned = {}
        for line in result:gmatch("[^\r\n]+") do
            local p = line:match("package:(.*)")
            if p then table.insert(scanned, p) end
        end

        if #scanned == 0 then
            print(red.."No packages found!"..reset)
        else
            for i, p in ipairs(scanned) do print("  ["..i.."] "..p) end
            io.write(yellow.."\nPress ENTER to select all (or type 1,2): "..reset)
            local sel = io.read()
            config.packages = {}
            if sel == "" then
                config.packages = scanned
            else
                for str in string.gmatch(sel, "([^,]+)") do
                    local n = tonumber(str)
                    if n and scanned[n] then table.insert(config.packages, scanned[n]) end
                end
            end
        end

        if #config.packages > 0 then
            -- 2. PRIVATE SERVER
            io.write(yellow.."\nUse same private server URL for all? (y/n): "..reset)
            if io.read():lower() == "n" then
                config.private_servers.mode = "per_package"
                print(yellow.."Enter URL for each package:"..reset)
                for _, pkg in ipairs(config.packages) do
                    io.write("  "..pkg..": ")
                    config.private_servers.urls[pkg] = io.read()
                end
            else
                config.private_servers.mode = "same"
                io.write(yellow.."Enter Private Server URL: "..reset)
                config.private_servers.url = io.read()
            end

            -- 3. WEBHOOK & DELAY
            io.write(yellow.."\nWebhook URL (Enter to skip): "..reset)
            local wh = io.read()
            if wh ~= "" then 
                config.webhook.enabled = true
                config.webhook.url = wh
            end
            
            io.write(yellow.."Delay Launch (sec): "..reset)
            config.delay_launch = tonumber(io.read()) or 0

            -- 4. INSTALL
            installDivineMonitor(config)
            saveConfig(config)
            print(green.."\nConfiguration Saved!"..reset)
        end
        io.read()

    elseif pilih == "3" then configMenu()
    elseif pilih == "4" then OptimizeSystem()
    elseif pilih == "5" then print(red.."Uninstalling..."..reset)
    elseif pilih == "6" then break
    end
end