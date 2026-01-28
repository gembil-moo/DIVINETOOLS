-- optimizer.lua
-- System Optimization Module for DIVINETOOLS

local config = require("modules.config")
local ui = require("modules.ui")
local utils = require("modules.utils")

local M = {}

-- Optimization presets
local PRESETS = {
    LIGHT = {
        name = "Light Optimization",
        description = "Basic cache clearing and memory optimization",
        actions = {
            clear_cache = true,
            kill_background = true,
            low_memory = false,
            disable_animations = false,
            remove_textures = false
        }
    },
    BALANCED = {
        name = "Balanced Optimization",
        description = "Good balance between performance and visual quality",
        actions = {
            clear_cache = true,
            kill_background = true,
            low_memory = true,
            disable_animations = true,
            remove_textures = false
        }
    },
    PERFORMANCE = {
        name = "Performance Mode",
        description = "Aggressive optimization for maximum performance",
        actions = {
            clear_cache = true,
            kill_background = true,
            low_memory = true,
            disable_animations = true,
            remove_textures = true,
            reduce_resolution = true
        }
    },
    GOD_MODE = {
        name = "GOD MODE",
        description = "Extreme optimization (removes textures, disables animations)",
        actions = {
            clear_cache = true,
            kill_background = true,
            low_memory = true,
            disable_animations = true,
            remove_textures = true,
            reduce_resolution = true,
            disable_sounds = true,
            aggressive_memory = true
        }
    }
}

-- Clear system cache
function M.clearSystemCache()
    print(ui.colors.yellow .. "[*] Clearing system cache..." .. ui.colors.reset)
    
    local commands = {
        "pm trim-caches 256G 2>/dev/null",
        "rm -rf /data/local/tmp/* 2>/dev/null",
        "rm -rf /data/system/dropbox/* 2>/dev/null",
        "rm -rf /data/system/usagestats/* 2>/dev/null",
        "rm -rf /data/tombstones/* 2>/dev/null"
    }
    
    local cleared = 0
    for _, cmd in ipairs(commands) do
        if os.execute(cmd) then
            cleared = cleared + 1
        end
    end
    
    print(ui.colors.green .. "[+] Cleared " .. cleared .. " cache locations" .. ui.colors.reset)
    return cleared
end

-- Kill background processes
function M.killBackgroundProcesses()
    print(ui.colors.yellow .. "[*] Killing background processes..." .. ui.colors.reset)
    
    local processes = {
        "com.facebook.katana",
        "com.instagram.android",
        "com.whatsapp",
        "com.twitter.android",
        "com.google.android.youtube",
        "com.android.chrome",
        "com.sec.android.app.launcher"
    }
    
    local killed = 0
    for _, process in ipairs(processes) do
        local cmd = "am force-stop " .. process .. " 2>/dev/null"
        if os.execute(cmd) then
            killed = killed + 1
            print(ui.colors.cyan .. "  → Killed: " .. process .. ui.colors.reset)
        end
    end
    
    -- Kill all non-essential services
    os.execute("am kill-all 2>/dev/null")
    
    print(ui.colors.green .. "[+] Killed " .. killed .. " background processes" .. ui.colors.reset)
    return killed
end

-- Enable low memory mode
function M.enableLowMemoryMode()
    print(ui.colors.yellow .. "[*] Enabling low memory mode..." .. ui.colors.reset)
    
    local commands = {
        "settings put global low_power 1",
        "settings put global low_power_mode 1",
        "settings put global app_standby_enabled 1",
        "settings put global app_auto_restriction_enabled 1"
    }
    
    for _, cmd in ipairs(commands) do
        os.execute("su -c '" .. cmd .. "' 2>/dev/null")
    end
    
    -- Set memory pressure level
    os.execute("echo 100 > /proc/sys/vm/swappiness 2>/dev/null")
    os.execute("echo 1 > /proc/sys/vm/drop_caches 2>/dev/null")
    
    print(ui.colors.green .. "[+] Low memory mode enabled" .. ui.colors.reset)
    return true
end

-- Disable animations
function M.disableAnimations()
    print(ui.colors.yellow .. "[*] Disabling animations..." .. ui.colors.reset)
    
    local animations = {
        "window_animation_scale",
        "transition_animation_scale", 
        "animator_duration_scale"
    }
    
    for _, anim in ipairs(animations) do
        os.execute("su -c 'settings put global " .. anim .. " 0' 2>/dev/null")
        print(ui.colors.cyan .. "  → Disabled: " .. anim .. ui.colors.reset)
    end
    
    print(ui.colors.green .. "[+] Animations disabled" .. ui.colors.reset)
    return true
end

-- Remove game textures
function M.removeGameTextures(packages)
    print(ui.colors.yellow .. "[*] Removing game textures..." .. ui.colors.reset)
    
    local texture_paths = {
        "/files/content/textures",
        "/files/content/sky",
        "/files/content/particles",
        "/files/content/sounds",
        "/files/content/meshes",
        "/files/content/decals",
        "/files/content/avatar"
    }
    
    local removed = 0
    for _, pkg in ipairs(packages) do
        for _, path in ipairs(texture_paths) do
            local full_path = "/data/data/" .. pkg .. path
            if os.execute("test -d " .. full_path .. " 2>/dev/null") then
                os.execute("rm -rf " .. full_path .. " 2>/dev/null")
                os.execute("mkdir -p " .. full_path .. " 2>/dev/null")
                os.execute("touch " .. full_path .. "/.nomedia 2>/dev/null")
                os.execute("chmod 444 " .. full_path .. " 2>/dev/null")
                removed = removed + 1
            end
        end
        print(ui.colors.cyan .. "  → Processed: " .. pkg .. ui.colors.reset)
    end
    
    print(ui.colors.green .. "[+] Removed textures from " .. #packages .. " packages" .. ui.colors.reset)
    return removed
end

-- Reduce screen resolution
function M.reduceScreenResolution()
    print(ui.colors.yellow .. "[*] Reducing screen resolution..." .. ui.colors.reset)
    
    -- Common low resolutions
    local resolutions = {
        {540, 960},   -- 540p
        {720, 1280},  -- 720p  
        {810, 1440}   -- Reduced 1080p
    }
    
    -- Get current resolution
    local current = utils.captureCommand("su -c 'wm size' 2>/dev/null")
    local original = current
    
    if current then
        current = current:match("Physical size: (%d+x%d+)") or "1080x2400"
        print(ui.colors.cyan .. "  Current: " .. current .. ui.colors.reset)
    end
    
    -- Set to 540p (lowest reasonable)
    local success = os.execute("su -c 'wm size 540x960' 2>/dev/null")
    
    if success then
        os.execute("su -c 'wm density 240' 2>/dev/null")
        print(ui.colors.green .. "[+] Resolution set to 540x960" .. ui.colors.reset)
        return original
    end
    
    return nil
end

-- Disable sounds
function M.disableSounds()
    print(ui.colors.yellow .. "[*] Disabling system sounds..." .. ui.colors.reset)
    
    local commands = {
        "settings put system volume_music 0",
        "settings put system volume_ring 0",
        "settings put system volume_system 0",
        "settings put system volume_notification 0",
        "settings put system volume_alarm 0",
        "settings put system sound_effects_enabled 0",
        "settings put system lockscreen_sounds_enabled 0",
        "settings put system haptic_feedback_enabled 0"
    }
    
    for _, cmd in ipairs(commands) do
        os.execute("su -c '" .. cmd .. "' 2>/dev/null")
    end
    
    print(ui.colors.green .. "[+] System sounds disabled" .. ui.colors.reset)
    return true
end

-- Enable aggressive memory management
function M.enableAggressiveMemory()
    print(ui.colors.yellow .. "[*] Enabling aggressive memory management..." .. ui.colors.reset)
    
    -- Linux kernel memory settings
    local memory_settings = {
        "/proc/sys/vm/swappiness = 100",
        "/proc/sys/vm/vfs_cache_pressure = 200",
        "/proc/sys/vm/dirty_ratio = 20",
        "/proc/sys/vm/dirty_background_ratio = 5",
        "/proc/sys/vm/min_free_kbytes = 32768",
        "/proc/sys/vm/oom_kill_allocating_task = 1"
    }
    
    for _, setting in ipairs(memory_settings) do
        local file, value = setting:match("(.+) = (.+)")
        if file and value then
            os.execute("su -c 'echo " .. value .. " > " .. file .. "' 2>/dev/null")
        end
    end
    
    -- Android service restrictions
    os.execute("su -c 'settings put global app_standby_enabled 1' 2>/dev/null")
    os.execute("su -c 'settings put global app_auto_restriction_enabled 1' 2>/dev/null")
    os.execute("su -c 'settings put global background_check_enabled 1' 2>/dev/null")
    
    print(ui.colors.green .. "[+] Aggressive memory management enabled" .. ui.colors.reset)
    return true
end

-- Optimize specific package
function M.optimizePackage(pkg, preset_name)
    local preset = PRESETS[preset_name] or PRESETS.BALANCED
    
    print(ui.colors.cyan .. "\n🔧 Optimizing: " .. pkg .. ui.colors.reset)
    print(ui.colors.yellow .. "  Preset: " .. preset.name .. ui.colors.reset)
    print(ui.colors.yellow .. "  " .. preset.description .. ui.colors.reset)
    
    -- Clear package cache
    if preset.actions.clear_cache then
        os.execute("su -c 'pm clear " .. pkg .. "' 2>/dev/null")
        print(ui.colors.green .. "  ✓ Cleared package cache" .. ui.colors.reset)
    end
    
    -- Remove textures if enabled
    if preset.actions.remove_textures then
        M.removeGameTextures({pkg})
    end
    
    return true
end

-- Run optimization preset
function M.runPreset(preset_name, packages)
    local preset = PRESETS[preset_name]
    if not preset then
        ui.showMessage("Invalid preset: " .. preset_name, "error")
        return false
    end
    
    print(ui.colors.cyan .. "\n🎯 RUNNING OPTIMIZATION PRESET" .. ui.colors.reset)
    ui.printSeparator(50, "─", ui.colors.cyan)
    print(ui.colors.green .. "  Name: " .. preset.name .. ui.colors.reset)
    print(ui.colors.yellow .. "  Description: " .. preset.description .. ui.colors.reset)
    ui.printSeparator(50, "─", ui.colors.cyan)
    
    local results = {
        preset = preset.name,
        timestamp = os.time(),
        actions = {}
    }
    
    -- Execute each action
    if preset.actions.clear_cache then
        ui.showLoading("Clearing system cache", 2)
        local cleared = M.clearSystemCache()
        table.insert(results.actions, {
            name = "clear_cache",
            result = cleared .. " locations cleared"
        })
    end
    
    if preset.actions.kill_background then
        ui.showLoading("Killing background processes", 2)
        local killed = M.killBackgroundProcesses()
        table.insert(results.actions, {
            name = "kill_background",
            result = killed .. " processes killed"
        })
    end
    
    if preset.actions.low_memory then
        ui.showLoading("Enabling low memory mode", 1)
        M.enableLowMemoryMode()
        table.insert(results.actions, {
            name = "low_memory",
            result = "enabled"
        })
    end
    
    if preset.actions.disable_animations then
        ui.showLoading("Disabling animations", 1)
        M.disableAnimations()
        table.insert(results.actions, {
            name = "disable_animations",
            result = "disabled"
        })
    end
    
    if preset.actions.remove_textures and packages then
        ui.showLoading("Removing game textures", 3)
        local removed = M.removeGameTextures(packages)
        table.insert(results.actions, {
            name = "remove_textures",
            result = removed .. " texture directories removed"
        })
    end
    
    if preset.actions.reduce_resolution then
        ui.showLoading("Reducing screen resolution", 2)
        local original = M.reduceScreenResolution()
        table.insert(results.actions, {
            name = "reduce_resolution",
            result = original and "reduced from " .. original or "failed"
        })
    end
    
    if preset.actions.disable_sounds then
        ui.showLoading("Disabling system sounds", 1)
        M.disableSounds()
        table.insert(results.actions, {
            name = "disable_sounds",
            result = "disabled"
        })
    end
    
    if preset.actions.aggressive_memory then
        ui.showLoading("Enabling aggressive memory", 2)
        M.enableAggressiveMemory()
        table.insert(results.actions, {
            name = "aggressive_memory",
            result = "enabled"
        })
    end
    
    -- Show summary
    print("\n" .. ui.colors.green .. "✅ OPTIMIZATION COMPLETE" .. ui.colors.reset)
    ui.printSeparator(50, "─", ui.colors.green)
    print(ui.colors.cyan .. "  Actions performed: " .. #results.actions .. ui.colors.reset)
    
    for _, action in ipairs(results.actions) do
        print(ui.colors.yellow .. "  ✓ " .. action.name .. ": " .. action.result .. ui.colors.reset)
    end
    
    ui.printSeparator(50, "─", ui.colors.green)
    
    return results
end

-- Reset to normal settings
function M.resetToNormal()
    print(ui.colors.yellow .. "[*] Resetting to normal settings..." .. ui.colors.reset)
    
    -- Reset screen resolution
    os.execute("su -c 'wm size reset' 2>/dev/null")
    os.execute("su -c 'wm density reset' 2>/dev/null")
    
    -- Re-enable animations
    local animations = {
        {"window_animation_scale", 1},
        {"transition_animation_scale", 1},
        {"animator_duration_scale", 1}
    }
    
    for _, anim in ipairs(animations) do
        os.execute("su -c 'settings put global " .. anim[1] .. " " .. anim[2] .. "' 2>/dev/null")
    end
    
    -- Re-enable sounds
    local sound_levels = {
        {"volume_music", 7},
        {"volume_ring", 7},
        {"volume_system", 7},
        {"volume_notification", 7},
        {"volume_alarm", 7},
        {"sound_effects_enabled", 1},
        {"lockscreen_sounds_enabled", 1},
        {"haptic_feedback_enabled", 1}
    }
    
    for _, sound in ipairs(sound_levels) do
        os.execute("su -c 'settings put system " .. sound[1] .. " " .. sound[2] .. "' 2>/dev/null")
    end
    
    -- Reset memory settings
    os.execute("su -c 'settings put global low_power 0' 2>/dev/null")
    os.execute("su -c 'settings put global app_standby_enabled 0' 2>/dev/null")
    
    print(ui.colors.green .. "[+] Settings reset to normal" .. ui.colors.reset)
    return true
end

-- Get current optimization status
function M.getOptimizationStatus()
    local status = {}
    
    -- Check screen resolution
    local resolution = utils.captureCommand("su -c 'wm size' 2>/dev/null")
    if resolution then
        status.resolution = resolution:match("Physical size: (.+)") or "Unknown"
    end
    
    -- Check animation scales
    local animations = {}
    local anim_names = {"window_animation_scale", "transition_animation_scale", "animator_duration_scale"}
    
    for _, anim in ipairs(anim_names) do
        local value = utils.captureCommand("su -c 'settings get global " .. anim .. "' 2>/dev/null")
        if value then
            animations[anim] = tonumber(value:gsub("%s+", "")) or 0
        end
    end
    status.animations = animations
    
    -- Check memory mode
    local low_power = utils.captureCommand("su -c 'settings get global low_power' 2>/dev/null")
    status.low_power_mode = low_power and low_power:match("1") ~= nil
    
    -- Check sounds
    local sounds_enabled = utils.captureCommand("su -c 'settings get system sound_effects_enabled' 2>/dev/null")
    status.sounds_enabled = sounds_enabled and sounds_enabled:match("1") ~= nil
    
    return status
end

-- Show optimization menu
function M.showMenu()
    local config_data = config.load()
    
    while true do
        ui.clearScreen()
        ui.printSeparator(54, "═", ui.colors.magenta)
        print("        " .. ui.colors.green .. "✦ DIVINE OPTIMIZER ✦" .. ui.colors.reset)
        ui.printSeparator(54, "═", ui.colors.magenta)
        
        print(ui.colors.cyan .. "  [1] Light Optimization" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. PRESETS.LIGHT.description .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [2] Balanced Optimization" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. PRESETS.BALANCED.description .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [3] Performance Mode" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. PRESETS.PERFORMANCE.description .. ui.colors.reset)
        
        print(ui.colors.red .. "\n  [4] GOD MODE (Extreme)" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. PRESETS.GOD_MODE.description .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [5] Custom Optimization" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Choose specific optimizations" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [6] Reset to Normal" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Restore default settings" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [7] Current Status" .. ui.colors.reset)
        print("      " .. ui.colors.yellow .. "Show optimization status" .. ui.colors.reset)
        
        print(ui.colors.cyan .. "\n  [8] Back to Main Menu" .. ui.colors.reset)
        
        ui.printSeparator(54, "═", ui.colors.magenta)
        
        io.write(ui.colors.yellow .. "\nSelect option (1-8): " .. ui.colors.reset)
        local choice = io.read():gsub("%s+", "")
        
        if choice == "1" then
            M.runPreset("LIGHT", config_data.packages)
            ui.pressToContinue()
            
        elseif choice == "2" then
            M.runPreset("BALANCED", config_data.packages)
            ui.pressToContinue()
            
        elseif choice == "3" then
            M.runPreset("PERFORMANCE", config_data.packages)
            ui.pressToContinue()
            
        elseif choice == "4" then
            if ui.confirm(ui.colors.red .. "WARNING: GOD MODE will remove textures and disable animations. Continue?" .. ui.colors.reset, ui.colors.red) then
                M.runPreset("GOD_MODE", config_data.packages)
            end
            ui.pressToContinue()
            
        elseif choice == "5" then
            M.showCustomMenu(config_data.packages)
            ui.pressToContinue()
            
        elseif choice == "6" then
            M.resetToNormal()
            ui.pressToContinue()
            
        elseif choice == "7" then
            M.showStatus()
            ui.pressToContinue()
            
        elseif choice == "8" then
            break
            
        else
            ui.showMessage("Invalid option!", "error")
            ui.pressToContinue()
        end
    end
end

-- Show custom optimization menu
function M.showCustomMenu(packages)
    ui.clearScreen()
    ui.printSeparator(50, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "✦ CUSTOM OPTIMIZATION ✦" .. ui.colors.reset)
    ui.printSeparator(50, "═", ui.colors.cyan)
    
    local selected = {}
    
    print(ui.colors.yellow .. "Select optimizations to apply:" .. ui.colors.reset)
    print()
    
    local options = {
        {"Clear system cache", "clear_cache"},
        {"Kill background processes", "kill_background"},
        {"Enable low memory mode", "low_memory"},
        {"Disable animations", "disable_animations"},
        {"Remove game textures", "remove_textures"},
        {"Reduce screen resolution", "reduce_resolution"},
        {"Disable system sounds", "disable_sounds"},
        {"Aggressive memory management", "aggressive_memory"}
    }
    
    for i, option in ipairs(options) do
        print(string.format("  [%d] %s", i, option[1]))
    end
    
    print()
    io.write(ui.colors.yellow .. "Enter selections (e.g., 1,3,5 or 'all'): " .. ui.colors.reset)
    local input = io.read():gsub("%s+", "")
    
    if input:lower() == "all" then
        for _, option in ipairs(options) do
            table.insert(selected, option[2])
        end
    else
        for str in input:gmatch("[^,]+") do
            local idx = tonumber(str)
            if idx and idx >= 1 and idx <= #options then
                table.insert(selected, options[idx][2])
            end
        end
    end
    
    if #selected == 0 then
        ui.showMessage("No optimizations selected!", "warning")
        return
    end
    
    -- Execute selected optimizations
    print(ui.colors.cyan .. "\n🎯 APPLYING CUSTOM OPTIMIZATIONS" .. ui.colors.reset)
    ui.printSeparator(50, "─", ui.colors.cyan)
    
    for _, opt in ipairs(selected) do
        if opt == "clear_cache" then
            M.clearSystemCache()
        elseif opt == "kill_background" then
            M.killBackgroundProcesses()
        elseif opt == "low_memory" then
            M.enableLowMemoryMode()
        elseif opt == "disable_animations" then
            M.disableAnimations()
        elseif opt == "remove_textures" then
            M.removeGameTextures(packages)
        elseif opt == "reduce_resolution" then
            M.reduceScreenResolution()
        elseif opt == "disable_sounds" then
            M.disableSounds()
        elseif opt == "aggressive_memory" then
            M.enableAggressiveMemory()
        end
    end
    
    print(ui.colors.green .. "\n✅ Custom optimizations applied!" .. ui.colors.reset)
end

-- Show current optimization status
function M.showStatus()
    ui.clearScreen()
    ui.printSeparator(50, "═", ui.colors.cyan)
    print("        " .. ui.colors.green .. "✦ OPTIMIZATION STATUS ✦" .. ui.colors.reset)
    ui.printSeparator(50, "═", ui.colors.cyan)
    
    local status = M.getOptimizationStatus()
    
    print(ui.colors.yellow .. "Screen Resolution:" .. ui.colors.reset)
    print("  " .. (status.resolution or "Unknown"))
    
    print(ui.colors.yellow .. "\nAnimations:" .. ui.colors.reset)
    if status.animations then
        for name, value in pairs(status.animations) do
            local state = value == 0 and ui.colors.red .. "DISABLED" or ui.colors.green .. "ENABLED"
            print(string.format("  %-25s: %s", name, state .. ui.colors.reset))
        end
    end
    
    print(ui.colors.yellow .. "\nMemory Mode:" .. ui.colors.reset)
    local mem_state = status.low_power_mode and ui.colors.red .. "LOW POWER" or ui.colors.green .. "NORMAL"
    print("  " .. mem_state .. ui.colors.reset)
    
    print(ui.colors.yellow .. "\nSounds:" .. ui.colors.reset)
    local sound_state = status.sounds_enabled and ui.colors.green .. "ENABLED" or ui.colors.red .. "DISABLED"
    print("  " .. sound_state .. ui.colors.reset)
    
    ui.printSeparator(50, "═", ui.colors.cyan)
end

-- Optimize for monitoring (pre-launch optimization)
function M.optimizeForMonitoring(config_data)
    print(ui.colors.cyan .. "\n🔧 PRE-MONITORING OPTIMIZATION" .. ui.colors.reset)
    
    local results = {}
    
    -- Clear caches if enabled
    if config_data.optimization.clear_cache_on_start then
        ui.showLoading("Clearing package caches", 2)
        for _, pkg in ipairs(config_data.packages) do
            os.execute("su -c 'pm clear " .. pkg .. "' 2>/dev/null")
        end
        table.insert(results, "Cleared package caches")
    end
    
    -- Apply GOD MODE if enabled
    if config_data.optimization.god_mode then
        ui.showLoading("Applying GOD MODE optimizations", 3)
        M.runPreset("GOD_MODE", config_data.packages)
        table.insert(results, "Applied GOD MODE")
    end
    
    -- Apply low resolution if enabled
    if config_data.optimization.low_resolution then
        ui.showLoading("Setting low resolution", 2)
        M.reduceScreenResolution()
        table.insert(results, "Set low resolution")
    end
    
    -- Summary
    if #results > 0 then
        print(ui.colors.green .. "\n✅ PRE-MONITORING OPTIMIZATION COMPLETE" .. ui.colors.reset)
        for _, result in ipairs(results) do
            print(ui.colors.yellow .. "  ✓ " .. result .. ui.colors.reset)
        end
    else
        print(ui.colors.yellow .. "\n⚠️  No optimizations applied" .. ui.colors.reset)
    end
    
    return results
end

-- Benchmark optimization
function M.runBenchmark()
    print(ui.colors.cyan .. "\n📊 RUNNING OPTIMIZATION BENCHMARK" .. ui.colors.reset)
    
    -- Get baseline
    local baseline_memory = utils.getMemoryUsage()
    local baseline_cpu = utils.getCPUUsage()
    
    print(ui.colors.yellow .. "Baseline measurements:" .. ui.colors.reset)
    print("  Memory: " .. (baseline_memory and baseline_memory.human or "N/A"))
    print("  CPU: " .. (baseline_cpu and baseline_cpu.human or "N/A"))
    
    -- Run light optimization
    print(ui.colors.cyan .. "\nRunning Light Optimization..." .. ui.colors.reset)
    M.runPreset("LIGHT", {})
    
    -- Get after measurements
    utils.sleep(2)  -- Wait for system to settle
    local after_memory = utils.getMemoryUsage()
    local after_cpu = utils.getCPUUsage()
    
    print(ui.colors.yellow .. "\nAfter optimization:" .. ui.colors.reset)
    print("  Memory: " .. (after_memory and after_memory.human or "N/A"))
    print("  CPU: " .. (after_cpu and after_cpu.human or "N/A"))
    
    -- Calculate improvements
    if baseline_memory and after_memory then
        local mem_improvement = baseline_memory.percent - after_memory.percent
        print(ui.colors.green .. "\n📈 Memory improvement: " .. string.format("%.1f%%", mem_improvement) .. ui.colors.reset)
    end
    
    -- Reset to normal
    M.resetToNormal()
    
    print(ui.colors.green .. "\n✅ Benchmark completed" .. ui.colors.reset)
end

return M