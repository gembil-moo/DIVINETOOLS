-- ===== WARNA ANSI =====
--[[ 
    💎 DIVINE MANAGER PRO - SILENT EDITION
    Fix: UI Anti-Meledak (Silent Execution) & Compact Layout
]]

local cjson = require "cjson"

-- WARNA
local iceblue = "\27[38;5;51m"
local green   = "\27[38;5;46m"
local red     = "\27[31m"
local yellow  = "\27[33m"
local white   = "\27[37m"
local reset   = "\27[0m"

local CONFIG_PATH = "config.json"

-- HELPER: JALANKAN PERINTAH TANPA SUARA (PENTING BIAR UI GAK RUSAK)
local function RunSilent(cmd)
    os.execute(cmd .. " > /dev/null 2>&1")
end

-- HELPER VISUAL
local function printBanner()
    io.write("\27[2J\27[H")
    print(iceblue..[[
██████╗ ██╗██╗   ██╗██╗███╗   ██╗███████╗
██╔══██╗██║██║   ██║██║████╗  ██║██╔════╝
██║  ██║██║██║   ██║██║██╔██╗ ██║█████╗  
██║  ██║██║╚██╗ ██╔╝██║██║╚██╗██║██╔══╝  
██████╔╝██║ ╚████╔╝ ██║██║ ╚████║███████╗
╚═════╝ ╚═╝  ╚═══╝  ╚═╝╚═╝  ╚═══╝╚══════╝]]..reset)
end

-- CONFIG
local function loadConfig()
    local f = io.open(CONFIG_PATH, "r")
    local cfg = {}
    if f then pcall(function() cfg = cjson.decode(f:read("*a")) f:close() end) end
    if not cfg.packages then cfg.packages = {} end
    if not cfg.webhook then cfg.webhook = { url = "", tag_everyone = false } end
    return cfg
end

local function saveConfig(cfg)
    local f = io.open(CONFIG_PATH, "w")
    if f then f:write(cjson.encode(cfg)) f:close() end
end

-- UI DASHBOARD (COMPACT VERSION)
local function GetSystemMemory()
    local h = io.popen("free -m")
    local res = h:read("*a") h:close()
    local total, used, free = res:match("Mem:%s+(%d+)%s+(%d+)%s+(%d+)")
    if not total then return "Unknown", "0%" end
    local pct = math.floor((free / total) * 100)
    return free .. "MB", pct .. "%"
end

local function DrawDashboard(packages, statuses, title_status)
    io.write("\27[H") -- Reset Kursor
    local memFree, memPct = GetSystemMemory()
    local colorMem = (tonumber(memPct) > 20) and green or red 
    
    print(iceblue.."========================================"..reset)
    print(iceblue.."   🚀 DIVINE MONITOR DASHBOARD 🚀       "..reset)
    print(iceblue.."========================================"..reset)
    print(yellow.." RAM    : "..colorMem..memFree.." ("..memPct..")"..reset)
    print(yellow.." ACTION : "..white..title_status..reset)
    print(iceblue.."----------------------------------------"..reset)
    print(white.." NO  PACKAGE        STATUS              "..reset)
    print(iceblue.."----------------------------------------"..reset)
    
    for i, pkg in ipairs(packages) do
        local shortName = pkg:gsub("com.roblox.", ""):sub(1, 10)
        local status = statuses[pkg] or "Idle"
        local sColor = white
        if status == "Online" then sColor = green
        elseif status == "Optimizing..." then sColor = yellow
        elseif status == "Resetting..." then sColor = red
        elseif status == "Launching..." then sColor = iceblue end
        
        print(string.format("%s [%d] %-12s %s%s%s", iceblue, i, shortName, sColor, status, reset))
    end
    print(iceblue.."========================================"..reset)
    print("\27[J") -- Bersihkan sisa layar bawah
end

-- SMART GRID
local function GetScreenResolution()
    local h = io.popen("wm size")
    local res = h:read("*a") h:close()
    local w, h = res:match("Physical size: (%d+)x(%d+)")
    return tonumber(w) or 1080, tonumber(h) or 2400
end

local function CalculateBounds(index, total_pkg, screenW, screenH)
    local cols, rows, y_offset
    if total_pkg == 1 then
        return string.format("0,%d,%d,%d", math.floor(screenH*0.15), screenW, screenH - math.floor(screenH*0.05))
    elseif total_pkg == 2 then
        cols, rows, y_offset = 1, 2, 120
    elseif total_pkg <= 8 then
        cols, rows, y_offset = 2, math.ceil(total_pkg/2), 80
        if rows < 2 then rows = 2 end
    else
        cols, rows, y_offset = 3, math.ceil(total_pkg/3), 60
    end
    
    local w, h = math.floor(screenW/cols), math.floor((screenH-y_offset)/rows)
    local i = index - 1
    local c, r = i % cols, math.floor(i / cols)
    if r >= rows then r = r % rows end
    local x1, y1 = c * w, y_offset + (r * h)
    return string.format("%d,%d,%d,%d", x1, y1, x1+w, y1+h)
end

-- GOD MODE (SILENT)
local function OptimizeSystem()
    os.execute("clear")
    print(green.."🚀 DIVINE OPTIMIZER"..reset)
    print(" [1] Clear Cache & RAM")
    print(" [2] Low Resolution (540p)")
    print(" [3] GOD MODE (Hapus Texture)")
    print(" [4] Reset Normal")
    print(" [5] Back")
    io.write(yellow.."\nSelect: "..reset)
    local l = io.read()

    if l == "1" then
        RunSilent("pm trim-caches 128G")
        RunSilent("am kill-all")
        print(green.."Done."..reset)
    elseif l == "2" then
        RunSilent("wm size 540x960")
        RunSilent("wm density 240")
        print(green.."Done."..reset)
    elseif l == "3" then
        print(red.."🔥 ACTIVATING GOD MODE..."..reset)
        RunSilent("settings put global window_animation_scale 0")
        RunSilent("settings put global transition_animation_scale 0")
        local cfg = loadConfig()
        local t = (#cfg.packages > 0) and cfg.packages or {"com.roblox.client"}
        for _, p in ipairs(t) do
            for _, s in ipairs({"/files/content/textures", "/files/content/sky", "/files/content/particles", "/files/content/sounds"}) do
                local f = "/data/data/"..p..s
                RunSilent("rm -rf "..f)
                RunSilent("touch "..f)
                RunSilent("chmod 444 "..f)
            end
            print(yellow.."-> Optimized: "..p..reset)
        end
        print(iceblue.."✅ GOD MODE ACTIVE!"..reset) io.read()
    elseif l == "4" then
        RunSilent("wm size reset")
        RunSilent("wm density reset")
        print(green.."Reset done."..reset)
    end
end

-- INJECTOR
local function InjectDivineLoader(cfg)
    print(green.."Injecting..."..reset)
    if not cfg.webhook.url or cfg.webhook.url == "" then print(red.."No Webhook!"..reset) return end
    local sc = [[
getgenv().DVN_WEBHOOK_URL = "]]..cfg.webhook.url..[["
getgenv().DVN_MENTION_EVERYONE = ]]..tostring(cfg.webhook.tag_everyone)..[[
loadstring(game:HttpGet("https://raw.githubusercontent.com/gembil-moo/DIVINETOOLS/refs/heads/main/Divine.lua"))()
]]
    for _, d in ipairs({"/storage/emulated/0/Delta/Autoexecute", "/storage/emulated/0/FluxusZ/autoexec", "/storage/emulated/0/Android/data/com.roblox.client/files/autoexec"}) do
        if io.popen("ls -d "..d.." 2>/dev/null"):read("*a") ~= "" then
            RunSilent("mkdir -p "..d)
            local f = io.open(d.."/dvn_loader.lua", "w")
            if f then f:write(sc) f:close() print(green.."✅ Injected: "..d..reset) end
        end
    end
end

-- WEBHOOK
local function SendWebhook(reason)
    local cfg = loadConfig()
    if not cfg.webhook.url or cfg.webhook.url == "" then return end
    local j = string.format('{"username":"DVN Monitor","content":"%s ⚠️ ALERT","embeds":[{"title":"Action Required","description":"%s","color":16711680}]}', (cfg.webhook.tag_everyone and "@everyone" or ""), tostring(reason))
    RunSilent("curl -H \"Content-Type: application/json\" -d '"..j.."' \""..cfg.webhook.url.."\"")
end

-- MAIN LOOP
while true do
    printBanner()
    print(red.." [1]"..reset.." START FARM (Dashboard)")
    print(red.." [2]"..reset.." Config Packages")
    print(red.." [3]"..reset.." Config Webhook")
    print(red.." [4]"..reset.." OPTIMIZE (God Mode)")
    print(red.." [5]"..reset.." INSTALL SCRIPT")
    print(red.." [6]"..reset.." Exit")
    io.write(yellow.."\nSelect: "..reset)
    local p = io.read()

    if p == "1" then
        local config = loadConfig()
        if #cfg.packages == 0 then print(red.."No Packages!"..reset) io.read() else
            RunSilent("clear")
            local scrW, scrH = GetScreenResolution()
            local sig = "/storage/emulated/0/Android/data/com.roblox.client/files/workspace/divine_relaunch.req"
            RunSilent("mkdir -p " .. sig:match("(.*/)") )
            RunSilent("rm "..sig)
            
            local st = {}
            local function RUI(a) DrawDashboard(cfg.packages, st, a) end
            
            -- PHASE 1: SILENT OPTIMIZE
            RUI("Maintenance...")
            RunSilent("pm trim-caches 128G")
            RunSilent("am kill-all")
            
            for _, pkg in ipairs(cfg.packages) do
                st[pkg] = "Optimizing..."
                RUI("Nuking Textures: "..pkg:gsub("com.roblox.",""))
                for _, s in ipairs({"/files/content/textures", "/files/content/sky"}) do
                    local f = "/data/data/"..pkg..s
                    RunSilent("rm -rf "..f)
                    RunSilent("touch "..f)
                    RunSilent("chmod 444 "..f)
                end
                os.execute("sleep 0.1")
            end
            
            -- PHASE 2: RESET
            for _, pkg in ipairs(cfg.packages) do
                st[pkg] = "Resetting..."
                RUI("Stopping Processes...")
                RunSilent("am force-stop "..pkg)
                os.execute("sleep 0.1")
                st[pkg] = "Ready"
            end
            
            -- PHASE 3: LAUNCH
            for i, pkg in ipairs(cfg.packages) do
                st[pkg] = "Launching..."
                RUI("Launching ["..i.."]")
                local b = CalculateBounds(i, #cfg.packages, scrW, scrH)
                RunSilent("am start -n "..pkg.."/com.roblox.client.Activity --windowingMode 5 --bounds "..b)
                os.execute("sleep 3")
                st[pkg] = "Online"
                RUI("Launching...")
            end
            
            -- PHASE 4: MONITOR
            RUI("Active")
            while true do
                local f = io.open(sig, "r")
                if f then
                    local r = f:read("*a") f:close() RunSilent("rm "..sig)
                    SendWebhook(r)
                    local t = cfg.packages[1]
                    st[t] = "Retry #1"
                    RUI("CRITICAL: Relaunching")
                    os.execute("sleep 1")
                    st[t] = "Resetting..."
                    RUI("Resetting...")
                    RunSilent("am force-stop "..t)
                    os.execute("sleep 2")
                    st[t] = "Launching..."
                    RUI("Relaunching...")
                    RunSilent("am start -n "..t.."/com.roblox.client.Activity --windowingMode 5 --bounds "..CalculateBounds(1, #cfg.packages, scrW, scrH))
                    st[t] = "Online"
                    RUI("Recovered")
                end
                RUI("Monitor Active")
                os.execute("sleep 3")
            end
        end
    elseif p == "2" then
        print(green.."Scanning..."..reset)
        local h = io.popen("pm list packages | grep com.roblox")
        local r = h:read("*a") h:close()
        local t = {}
        for l in r:gmatch("package:([^\n]+)") do table.insert(t, l) print("["..#t.."] "..l) end
        io.write(yellow.."Select (e.g. 1,2): "..reset)
        local s = io.read()
        local c = loadConfig()
        c.packages = {}
        for n in s:gmatch("([^,]+)") do if t[tonumber(n)] then table.insert(c.packages, t[tonumber(n)]) end end
        saveConfig(c) print(green.."Saved!"..reset) os.execute("sleep 1")
    elseif p == "3" then
        local c = loadConfig()
        io.write(yellow.."Webhook URL: "..reset) local u = io.read()
        if u ~= "" then c.webhook.url = u end
        io.write(yellow.."Tag Everyone (y/n): "..reset) c.webhook.tag_everyone = (io.read():lower()=="y")
        saveConfig(c) print(green.."Saved!"..reset) os.execute("sleep 1")
    elseif p == "4" then OptimizeSystem()
    elseif p == "5" then InjectDivineLoader(loadConfig()) io.read()
    elseif p == "6" then break end
end