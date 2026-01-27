--[[
    💎 DIVINE MONITOR (PURE MONITORING)
    Filename: Divine.lua
    Fungsi: Hanya Monitor Status & Kirim Webhook (Tanpa Auto Farm)
]]

local CoreGui = game:GetService("CoreGui")
local SIGNAL_FILE = "divine_relaunch.req"

local function RequestRelaunch(reason)
    writefile(SIGNAL_FILE, reason) 
end

-- === LOGIKA MONITOR ===

-- 1. Hapus sinyal lama (Tanda login sukses)
if isfile(SIGNAL_FILE) then delfile(SIGNAL_FILE) end

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

print("✅ Divine Monitor Active (Log Only)")