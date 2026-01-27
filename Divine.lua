--[[
    💎 DIVINE MONITOR (PURE MONITORING)
    Filename: Divine.lua
    Fungsi: Hanya Monitor Status & Kirim Webhook (Tanpa Auto Farm)
]]

-- 1. AMBIL SETTINGAN DARI LOADER (TERMUX)
local UserWebhook = getgenv().DVN_WEBHOOK_URL or ""
local MentionEveryone = getgenv().DVN_MENTION_EVERYONE or false
local BotAvatar = "https://cdn.discordapp.com/attachments/1451798194928353437/1463570214829555878/profil_bot.png?ex=69798fbb&is=69783e3b&hm=acc376e404e924d7c4cba5a1c97199077a08f9fc5321ce5ffd23153090350e05&"

-- Service Roblox
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RBXAnalytics = game:GetService("RbxAnalyticsService")
local CoreGui = game:GetService("CoreGui")

local SIGNAL_FILE = "divine_relaunch.req"

-- === FUNGSI KIRIM WEBHOOK ===
local function SendWebhook(status, reason)
    -- Cek validitas Webhook
    if UserWebhook == "" or UserWebhook == "LINK_WEBHOOK_DISINI" then return end

    local isCritical = (status == "CRITICAL")
    local color = isCritical and 0xFF0000 or 0x57F287 
    local title = isCritical and "⚠️ CRITICAL ALERT" or "✅ Account Recovered"
    local desc = isCritical and "Action required immediately." or "Everything is back to normal."
    
    local mem = math.floor(Stats:GetTotalMemoryUsageMb()) .. " MB"
    local deviceId = RBXAnalytics:GetClientId()
    local ping = "0ms"
    pcall(function() ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString():split(" ")[1]) .. "ms" end)
    
    local s = workspace.DistributedGameTime
    local uptime = string.format("%02dh %02dm %02ds", math.floor(s/3600), math.floor((s%3600)/60), math.floor(s%60))

    local fields = {
        {name = "👤 Account", value = "||" .. LocalPlayer.Name .. "||", inline = true},
        {name = "📱 Device", value = "||" .. deviceId:sub(1,15) .. "...||", inline = true},
        {name = "📝 Reason", value = "```" .. reason .. "```", inline = false},
        {name = "⚙️ Stats", value = "💾 Mem: " .. mem .. " | 📶 Ping: " .. ping .. " | ⏱️ " .. uptime, inline = false}
    }

    local payload = {
        username = "DVN Monitor",
        avatar_url = BotAvatar,
        content = (isCritical and MentionEveryone) and "@everyone" or nil,
        embeds = {{
            title = title,
            description = desc,
            color = color,
            fields = fields,
            footer = {text = "Divine Tools • discord.gg/dvn", icon_url = BotAvatar},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    request({
        Url = UserWebhook,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(payload)
    })
end

local function RequestRelaunch(reason)
    writefile(SIGNAL_FILE, reason) 
    SendWebhook("CRITICAL", reason)
end

-- === LOGIKA MONITOR ===

-- 1. Hapus sinyal lama (Tanda login sukses)
if isfile(SIGNAL_FILE) then delfile(SIGNAL_FILE) end
SendWebhook("NORMAL", "Account is back online!")

-- 2. Deteksi Error/Disconnect
CoreGui.RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
    if child.Name == "ErrorPrompt" then
        local msg = "Unknown Error"
        pcall(function() msg = child.MessageArea.ErrorFrame.ErrorMessage.Text end)
        RequestRelaunch("DISCONNECTED: " .. msg)
    end
end)

-- 3. Deteksi Key System Executor
spawn(function()
    while wait(10) do
        local ui = CoreGui:FindFirstChild("DeltaKeySystem") or CoreGui:FindFirstChild("FluxusKeySystem") or CoreGui:FindFirstChild("CodexKeySystem")
        if ui then RequestRelaunch("KEY SYSTEM DETECTED") end
    end
end)

print("✅ Divine Monitor Active (Monitoring Only)")