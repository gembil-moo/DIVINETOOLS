-- monitor.lua
-- Main Monitoring Module for DIVINETOOLS

local config = require("modules.config")
local ui = require("modules.ui")
local utils = require("modules.utils")
local webhook = require("modules.webhook")  -- Will be created later

local M = {}

-- Status tracking
local statuses = {}
local cached_users = {}
local process_pids = {}
local start_time = nil
local monitor_running = false

-- Initialize monitoring
function M.initialize(config_data)
    print(ui.colors.cyan .. "[*] Initializing Divine Monitor v2.0..." .. ui.colors.reset)
    
    -- Clear previous statuses
    statuses = {}
    cached_users = {}
    process_pids = {}
    
    -- Set initial statuses
    for _, pkg in ipairs(config_data.packages) do
        statuses[pkg] = "IDLE"
        cached_users[pkg] = config.getUsername(pkg)
    end
    
    start_time = os.time()
    monitor_running = true
    
    print(ui.colors.green .. "[+] Monitoring initialized for " .. #config_data.packages .. " package(s)" .. ui.colors.reset)
end

-- Get private server URL for package
function M.getPrivateServerURL(pkg, config_data)
    if config_data.private_servers.mode == "same" then
        return config_data.private_servers.url
    elseif config_data.private_servers.mode == "per_package" then
        return config_data.private_servers.urls[pkg]
    end
    return nil
end

-- Stop package
function M.stopPackage(pkg)
    print(ui.colors.yellow .. "[*] Stopping: " .. pkg .. ui.colors.reset)
    
    -- Force stop the package
    local cmd = "am force-stop " .. pkg .. " >/dev/null 2>&1"
    os.execute(cmd)
    
    -- Kill any remaining processes
    os.execute("pkill -f " .. pkg .. " 2>/dev/null")
    
    statuses[pkg] = "STOPPED"
    return true
end

-- Clear package cache
function M.clearPackageCache(pkg)
    print(ui.colors.yellow .. "[*] Clearing cache: " .. pkg .. ui.colors.reset)
    
    local cmd = "su -c 'pm clear " .. pkg .. "' 2>/dev/null"
    local success = os.execute(cmd)
    
    if success then
        statuses[pkg] = "CACHE_CLEARED"
    else
        statuses[pkg] = "CACHE_CLEAR_FAILED"
    end
    
    return success
end

-- Optimize package (GOD MODE)
function M.optimizePackage(pkg, god_mode)
    statuses[pkg] = "OPTIMIZING"
    
    if god_mode then
        -- Disable animations
        os.execute("settings put global window_animation_scale 0 2>/dev/null")
        os.execute("settings put global transition_animation_scale 0 2>/dev/null")
        os.execute("settings put global animator_duration_scale 0 2>/dev/null")
        
        -- Remove textures
        local paths = {
            "/files/content/textures",
            "/files/content/sky",
            "/files/content/particles",
            "/files/content/sounds",
            "/files/content/meshes"
        }
        
        for _, subpath in ipairs(paths) do
            local full_path = "/data/data/" .. pkg .. subpath
            os.execute("rm -rf " .. full_path .. " 2>/dev/null")
            os.execute("mkdir -p " .. full_path .. " 2>/dev/null")
            os.execute("touch " .. full_path .. "/.nomedia 2>/dev/null")
        end
        
        print(ui.colors.magenta .. "[GOD MODE] Optimized: " .. pkg .. ui.colors.reset)
    end
    
    -- Lower resolution if enabled
    -- This would be handled by the optimizer module
    
    statuses[pkg] = "OPTIMIZED"
    return true
end

-- Launch package
function M.launchPackage(pkg, config_data, screen_width, screen_height, index)
    statuses[pkg] = "LAUNCHING"
    
    -- Get window bounds
    local bounds = ui.calculateBounds(index, #config_data.packages, screen_width, screen_height)
    
    -- Stop package first (clean start)
    M.stopPackage(pkg)
    utils.sleep(0.5)
    
    -- Launch command
    local launch_cmd = string.format(
        "am start -S -n %s/com.roblox.client.startup.ActivitySplash --display %d",
        pkg, index
    )
    
    print(ui.colors.cyan .. "[*] Launching: " .. pkg .. " with bounds: " .. bounds .. ui.colors.reset)
    
    -- Execute launch
    local success, err = utils.executeWithTimeout(launch_cmd, 10)
    
    if not success then
        statuses[pkg] = "LAUNCH_FAILED"
        print(ui.colors.red .. "[!] Failed to launch: " .. pkg .. " - " .. err .. ui.colors.reset)
        return false
    end
    
    -- Wait for app to initialize
    utils.sleep(3, "Waiting for app initialization")
    
    -- Join private server if configured
    local ps_url = M.getPrivateServerURL(pkg, config_data)
    if ps_url and ps_url ~= "" then
        statuses[pkg] = "JOINING_SERVER"
        
        local join_cmd = string.format(
            'am start -a android.intent.action.VIEW -d "%s" -p %s',
            ps_url, pkg
        )
        
        print(ui.colors.cyan .. "[*] Joining private server: " .. pkg .. ui.colors.reset)
        os.execute(join_cmd .. " >/dev/null 2>&1")
        
        utils.sleep(2, "Joining server")
    end
    
    -- Apply delays if configured
    if config_data.delays.launch > 0 then
        statuses[pkg] = "WAITING_DELAY"
        utils.sleep(config_data.delays.launch, "Launch delay")
    end
    
    statuses[pkg] = "ONLINE"
    return true
end

-- Monitor package status
function M.checkPackageStatus(pkg)
    -- Check if package is running
    local cmd = string.format("ps | grep %s | grep -v grep", pkg)
    local output = utils.captureCommand(cmd)
    
    if output and output ~= "" then
        return "RUNNING"
    end
    
    -- Check if app is in foreground
    local fg_cmd = "dumpsys window windows | grep -E 'mCurrentFocus|mFocusedApp'"
    local fg_output = utils.captureCommand(fg_cmd)
    
    if fg_output and fg_output:match(pkg) then
        return "FOREGROUND"
    end
    
    return "STOPPED"
end

-- Restart package if crashed
function M.autoRestartPackage(pkg, config_data, attempt)
    attempt = attempt or 1
    
    if attempt > config_data.monitoring.max_restart_attempts then
        print(ui.colors.red .. "[!] Max restart attempts reached for: " .. pkg .. ui.colors.reset)
        statuses[pkg] = "RESTART_FAILED"
        return false
    end
    
    print(ui.colors.yellow .. "[!] Restarting: " .. pkg .. " (attempt " .. attempt .. ")" .. ui.colors.reset)
    
    -- Stop and relaunch
    M.stopPackage(pkg)
    utils.sleep(1)
    
    -- We need screen dimensions, but we'll use defaults for auto-restart
    local success = M.launchPackage(pkg, config_data, 1080, 2400, 1)
    
    if success then
        statuses[pkg] = "RESTARTED"
        return true
    else
        -- Wait and retry
        utils.sleep(2)
        return M.autoRestartPackage(pkg, config_data, attempt + 1)
    end
end

-- Update dashboard
function M.updateDashboard(config_data)
    local system_info = ui.getSystemInfo()
    
    -- Update statuses based on actual state
    for _, pkg in ipairs(config_data.packages) do
        local actual_status = M.checkPackageStatus(pkg)
        
        if statuses[pkg] == "ONLINE" and actual_status == "STOPPED" then
            if config_data.monitoring.auto_restart then
                statuses[pkg] = "CRASHED_RESTARTING"
            else
                statuses[pkg] = "CRASHED"
            end
        elseif statuses[pkg] == "CRASHED_RESTARTING" then
            -- Already handled
        elseif actual_status == "RUNNING" and statuses[pkg] ~= "ONLINE" then
            statuses[pkg] = "ONLINE"
        end
    end
    
    -- Draw dashboard
    ui.drawDashboard(statuses, config_data, cached_users, system_info)
end

-- Main monitoring loop
function M.monitoringLoop(config_data)
    print(ui.colors.green .. "[+] Starting monitoring loop..." .. ui.colors.reset)
    print(ui.colors.cyan .. "[*] Press CTRL+C to stop" .. ui.colors.reset)
    
    -- Get screen resolution
    local screen_width, screen_height = ui.getScreenResolution()
    print(ui.colors.yellow .. "[*] Screen resolution: " .. screen_width .. "x" .. screen_height .. ui.colors.reset)
    
    -- Initial optimization phase
    if config_data.optimization.clear_cache_on_start then
        print(ui.colors.yellow .. "[*] Initial optimization phase..." .. ui.colors.reset)
        
        for i, pkg in ipairs(config_data.packages) do
            ui.showProgress("Optimizing packages", i, #config_data.packages)
            
            M.stopPackage(pkg)
            M.clearPackageCache(pkg)
            
            if config_data.optimization.god_mode then
                M.optimizePackage(pkg, true)
            end
        end
        print() -- New line after progress
    end
    
    -- Main launch sequence
    local launch_sequence = function()
        for i, pkg in ipairs(config_data.packages) do
            M.launchPackage(pkg, config_data, screen_width, screen_height, i)
            
            -- Delay between packages if configured
            if i < #config_data.packages and config_data.delays.between_packages > 0 then
                utils.sleep(config_data.delays.between_packages, "Delay between packages")
            end
        end
    end
    
    -- Execute launch sequence
    local launch_success, launch_error = pcall(launch_sequence)
    
    if not launch_success then
        print(ui.colors.red .. "[!] Launch sequence failed: " .. launch_error .. ui.colors.reset)
        return false
    end
    
    -- Monitoring phase
    local last_status_update = 0
    local last_webhook_update = 0
    local loop_count = 0
    
    while monitor_running do
        loop_count = loop_count + 1
        
        -- Update dashboard
        M.updateDashboard(config_data)
        
        -- Check for crashes and auto-restart
        for _, pkg in ipairs(config_data.packages) do
            if statuses[pkg] == "CRASHED_RESTARTING" then
                M.autoRestartPackage(pkg, config_data)
            end
        end
        
        -- Send webhook updates if enabled
        if config_data.webhook.enabled then
            local current_time = os.time()
            
            -- Initial webhook notification
            if last_webhook_update == 0 then
                -- Send initial status
                -- webhook.sendStatusUpdate(statuses, config_data)
                last_webhook_update = current_time
            end
            
            -- Periodic updates
            if current_time - last_webhook_update >= (config_data.webhook.interval * 60) then
                -- webhook.sendStatusUpdate(statuses, config_data)
                last_webhook_update = current_time
            end
        end
        
        -- Check if relaunch loop is needed
        if config_data.delays.relaunch > 0 then
            local elapsed = utils.elapsedTime(start_time)
            
            if elapsed >= (config_data.delays.relaunch * 60) then
                print(ui.colors.yellow .. "[*] Relaunch loop triggered after " .. 
                      config_data.delays.relaunch .. " minutes" .. ui.colors.reset)
                
                -- Stop all packages
                for _, pkg in ipairs(config_data.packages) do
                    M.stopPackage(pkg)
                end
                
                -- Wait and restart
                utils.sleep(5, "Preparing for relaunch")
                
                -- Reset start time
                start_time = os.time()
                
                -- Relaunch
                launch_sequence()
            end
        end
        
        -- Small delay to prevent high CPU usage
        utils.sleep(config_data.display.refresh_rate)
        
        -- Check for user interrupt (non-blocking)
        if M.checkForInterrupt() then
            break
        end
    end
    
    return true
end

-- Check for user interrupt
function M.checkForInterrupt()
    -- Non-blocking check for keypress
    local handle = io.popen("timeout 0.1 cat 2>/dev/null", "r")
    if handle then
        local input = handle:read("*a")
        handle:close()
        
        if input and (input:match("q") or input:match("Q") or input:match("\3")) then  -- \3 is CTRL+C
            return true
        end
    end
    
    return false
end

-- Stop monitoring
function M.stopMonitoring()
    print(ui.colors.yellow .. "[*] Stopping monitoring..." .. ui.colors.reset)
    
    monitor_running = false
    
    -- Stop all packages
    for pkg, _ in pairs(statuses) do
        M.stopPackage(pkg)
    end
    
    -- Reset animations if GOD MODE was enabled
    os.execute("settings put global window_animation_scale 1 2>/dev/null")
    os.execute("settings put global transition_animation_scale 1 2>/dev/null")
    os.execute("settings put global animator_duration_scale 1 2>/dev/null")
    
    -- Kill any remaining processes
    for _, pid in pairs(process_pids) do
        os.execute("kill -9 " .. pid .. " 2>/dev/null")
    end
    
    print(ui.colors.green .. "[+] Monitoring stopped." .. ui.colors.reset)
    print(ui.colors.cyan .. "[*] Total runtime: " .. utils.formatTime(utils.elapsedTime(start_time)) .. ui.colors.reset)
end

-- Get monitoring statistics
function M.getStatistics()
    if not start_time then
        return nil
    end
    
    local stats = {
        runtime = utils.elapsedTime(start_time),
        packages = #config.load().packages,
        running = 0,
        stopped = 0,
        crashed = 0
    }
    
    for _, status in pairs(statuses) do
        if status == "ONLINE" or status == "RUNNING" then
            stats.running = stats.running + 1
        elseif status == "STOPPED" or status == "IDLE" then
            stats.stopped = stats.stopped + 1
        elseif status:match("CRASH") or status:match("FAIL") then
            stats.crashed = stats.crashed + 1
        end
    end
    
    return stats
end

-- Export monitoring data
function M.exportData(format)
    format = format or "json"
    
    local data = {
        timestamp = os.time(),
        statistics = M.getStatistics(),
        packages = {},
        config = config.load()
    }
    
    for pkg, status in pairs(statuses) do
        table.insert(data.packages, {
            name = pkg,
            status = status,
            user = cached_users[pkg],
            last_check = os.time()
        })
    end
    
    if format == "json" then
        local cjson = require("cjson")
        return cjson.encode(data)
    elseif format == "text" then
        local lines = {}
        table.insert(lines, "DIVINETOOLS Monitoring Report")
        table.insert(lines, "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
        table.insert(lines, "")
        
        if data.statistics then
            table.insert(lines, "Statistics:")
            table.insert(lines, "  Runtime: " .. utils.formatTime(data.statistics.runtime))
            table.insert(lines, "  Packages: " .. data.statistics.packages)
            table.insert(lines, "  Running: " .. data.statistics.running)
            table.insert(lines, "  Stopped: " .. data.statistics.stopped)
            table.insert(lines, "  Crashed: " .. data.statistics.crashed)
            table.insert(lines, "")
        end
        
        table.insert(lines, "Package Status:")
        for _, pkg_data in ipairs(data.packages) do
            table.insert(lines, string.format("  %-30s: %-15s (%s)", 
                pkg_data.name, pkg_data.status, pkg_data.user or "N/A"))
        end
        
        return table.concat(lines, "\n")
    end
    
    return nil
}

-- Save monitoring report
function M.saveReport()
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local filename = "logs/monitor_report_" .. timestamp .. ".json"
    
    local data = M.exportData("json")
    if data then
        utils.writeFile(filename, data)
        print(ui.colors.green .. "[+] Report saved: " .. filename .. ui.colors.reset)
        return filename
    end
    
    return nil
end

-- Start monitoring (main entry point)
function M.start(config_data)
    -- Check if packages are configured
    if not config_data or #config_data.packages == 0 then
        ui.showMessage("No packages configured!", "error")
        ui.showMessage("Please run First Configuration first", "info")
        return false
    end
    
    -- Check root access
    if not utils.isRootAvailable() then
        ui.showMessage("Root access is required for monitoring!", "warning")
        
        if not ui.confirm("Continue with limited functionality?", ui.colors.yellow) then
            return false
        end
    end
    
    -- Initialize
    M.initialize(config_data)
    
    -- Setup signal handler for graceful shutdown
    local function signalHandler()
        M.stopMonitoring()
        os.exit(0)
    end
    
    -- Try to setup signal handler
    local ok, posix = pcall(require, "posix.signal")
    if ok then
        posix.signal(posix.SIGINT, signalHandler)
    end
    
    -- Start monitoring
    local success, err = pcall(function()
        return M.monitoringLoop(config_data)
    end)
    
    -- Handle errors
    if not success then
        ui.showMessage("Monitoring error: " .. tostring(err), "error")
        
        -- Log error
        utils.log("Monitoring error: " .. tostring(err), "ERROR")
        
        -- Save error report
        M.saveReport()
    end
    
    -- Stop monitoring
    M.stopMonitoring()
    
    -- Show statistics
    local stats = M.getStatistics()
    if stats then
        print(ui.colors.cyan .. "\n📊 MONITORING STATISTICS:" .. ui.colors.reset)
        print(ui.colors.cyan .. "──────────────────────────" .. ui.colors.reset)
        print("  Runtime:    " .. utils.formatTime(stats.runtime))
        print("  Packages:   " .. stats.packages)
        print("  Running:    " .. stats.running)
        print("  Stopped:    " .. stats.stopped)
        print("  Crashed:    " .. stats.crashed)
        print(ui.colors.cyan .. "──────────────────────────" .. ui.colors.reset)
    end
    
    -- Ask to save report
    if ui.confirm("\nSave monitoring report?", ui.colors.cyan) then
        M.saveReport()
    end
    
    return success
end

-- Quick monitoring (single package)
function M.quickMonitor(pkg, ps_url)
    local temp_config = {
        packages = {pkg},
        private_servers = {
            mode = "same",
            url = ps_url or "",
            urls = {}
        },
        delays = {
            launch = 0,
            relaunch = 0,
            between_packages = 0
        },
        display = {
            mask_username = true,
            show_memory = true,
            show_time = true,
            refresh_rate = 1
        },
        optimization = {
            clear_cache_on_start = false,
            god_mode = false,
            low_resolution = false
        },
        monitoring = {
            check_interval = 10,
            auto_restart = true,
            max_restart_attempts = 3
        }
    }
    
    print(ui.colors.green .. "[+] Starting quick monitor for: " .. pkg .. ui.colors.reset)
    return M.start(temp_config)
end

-- Test monitoring without actual launch
function M.testMode(config_data)
    print(ui.colors.yellow .. "[*] TEST MODE - No actual packages will be launched" .. ui.colors.reset)
    
    -- Simulate monitoring
    for _, pkg in ipairs(config_data.packages) do
        statuses[pkg] = "TEST_ONLINE"
        cached_users[pkg] = "test_user_" .. pkg:sub(-3)
    end
    
    local test_loop = 0
    monitor_running = true
    
    while monitor_running and test_loop < 10 do
        test_loop = test_loop + 1
        
        -- Update some statuses randomly
        if test_loop % 3 == 0 then
            for pkg, _ in pairs(statuses) do
                if math.random() > 0.7 then
                    statuses[pkg] = "TEST_CRASHED"
                else
                    statuses[pkg] = "TEST_ONLINE"
                end
            end
        end
        
        M.updateDashboard(config_data)
        utils.sleep(1)
        
        if M.checkForInterrupt() then
            break
        end
    end
    
    monitor_running = false
    print(ui.colors.green .. "[+] Test mode completed" .. ui.colors.reset)
end

return M