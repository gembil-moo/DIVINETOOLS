-- ui.lua
-- User Interface Module for DIVINETOOLS

local M = {}

-- ANSI Color Codes
M.colors = {
    reset = "\27[0m",
    black = "\27[30m",
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    magenta = "\27[35m",
    cyan = "\27[36m",
    white = "\27[37m",
    iceblue = "\27[38;5;51m",
    bright_red = "\27[91m",
    bright_green = "\27[92m",
    bright_yellow = "\27[93m",
    bright_blue = "\27[94m",
    bright_magenta = "\27[95m",
    bright_cyan = "\27[96m",
    bright_white = "\27[97m",
    bg_black = "\27[40m",
    bg_red = "\27[41m",
    bg_green = "\27[42m",
    bg_yellow = "\27[43m",
    bg_blue = "\27[44m",
    bg_magenta = "\27[45m",
    bg_cyan = "\27[46m",
    bg_white = "\27[47m"
}

-- DIVINE ASCII Art
M.banner = {
    "██████╗ ██╗██╗   ██╗██╗███╗   ██╗███████╗",
    "██╔══██╗██║██║   ██║██║████╗  ██║██╔════╝", 
    "██║  ██║██║██║   ██║██║██╔██╗ ██║█████╗  ",
    "██║  ██║██║╚██╗ ██╔╝██║██║╚██╗██║██╔══╝  ",
    "██████╔╝██║ ╚████╔╝ ██║██║ ╚████║███████╗",
    "╚═════╝ ╚═╝  ╚═══╝  ╚═╝╚═╝  ╚═══╝╚══════╝"
}

-- Clear screen (ANSI escape code)
function M.clearScreen()
    io.write("\27[2J\27[H")
    io.flush()
end

-- Print separator line
function M.printSeparator(width, char, color)
    width = width or 50
    char = char or "═"
    color = color or M.colors.red
    
    print(color .. string.rep(char, width) .. M.colors.reset)
end

-- Print banner with colors
function M.printBanner(version)
    M.clearScreen()
    M.printSeparator(54, "═", M.colors.iceblue)
    
    for _, line in ipairs(M.banner) do
        print(M.colors.iceblue .. line .. M.colors.reset)
    end
    
    print(M.colors.yellow .. "    Your Monitoring Assistant" .. M.colors.reset)
    
    if version then
        print(M.colors.green .. "        ✦ VERSION " .. version .. " ✦" .. M.colors.reset)
    end
    
    M.printSeparator(54, "═", M.colors.iceblue)
end

-- Show message with type
function M.showMessage(text, msg_type)
    local color = M.colors.white
    local prefix = ""
    
    if msg_type == "error" then
        color = M.colors.red
        prefix = "[ERROR] "
    elseif msg_type == "warning" then
        color = M.colors.yellow
        prefix = "[WARNING] "
    elseif msg_type == "success" then
        color = M.colors.green
        prefix = "[SUCCESS] "
    elseif msg_type == "info" then
        color = M.colors.cyan
        prefix = "[INFO] "
    end
    
    print(color .. prefix .. text .. M.colors.reset)
end

-- Get confirmation from user
function M.confirm(prompt, color)
    color = color or M.colors.yellow
    io.write(color .. prompt .. " (y/n): " .. M.colors.reset)
    local answer = io.read():lower()
    return answer == "y" or answer == "yes"
end

-- Get number input with validation
function M.getNumberInput(prompt, min, max)
    while true do
        io.write(M.colors.yellow .. prompt .. M.colors.reset)
        local input = io.read()
        local number = tonumber(input)
        
        if number and (min == nil or number >= min) and (max == nil or number <= max) then
            return number
        end
        
        M.showMessage("Invalid input. Please enter a number" .. 
                     (min and " between " .. min .. " and " .. max or "") .. ".", "error")
    end
end

-- Press any key to continue
function M.pressToContinue(prompt)
    prompt = prompt or "Press ENTER to continue..."
    print()
    io.write(M.colors.cyan .. prompt .. M.colors.reset)
    io.read()
end

-- Show progress bar
function M.showProgress(title, current, total, width)
    width = width or 30
    local percentage = math.floor((current / total) * 100)
    local filled = math.floor(width * current / total)
    local empty = width - filled
    
    local bar = M.colors.green .. string.rep("█", filled) .. 
                M.colors.yellow .. string.rep("░", empty) .. M.colors.reset
    
    io.write(string.format("\r%s [%s] %3d%% (%d/%d)", 
                          M.colors.cyan .. title .. M.colors.reset,
                          bar, percentage, current, total))
    io.flush()
    
    if current == total then
        print() -- New line when complete
    end
end

-- Create menu from table
function M.createMenu(title, items, border_color)
    border_color = border_color or M.colors.cyan
    
    M.clearScreen()
    M.printSeparator(50, "═", border_color)
    print("        " .. M.colors.green .. title .. M.colors.reset)
    M.printSeparator(50, "═", border_color)
    
    for i, item in ipairs(items) do
        print(string.format("  [%d] %s", i, item))
    end
    
    M.printSeparator(50, "═", border_color)
end

-- Draw dashboard
function M.drawDashboard(statuses, config, cached_users, system_info)
    M.clearScreen()
    
    -- Header
    print(M.colors.iceblue .. "╔══════════════════════════════════════════════════╗" .. M.colors.reset)
    print(M.colors.iceblue .. "║           🚀 DIVINE MONITOR DASHBOARD 🚀         ║" .. M.colors.reset)
    print(M.colors.iceblue .. "╠══════════════════════════════════════════════════╣" .. M.colors.reset)
    
    -- System info
    if system_info then
        if system_info.memory then
            print(M.colors.iceblue .. "║" .. M.colors.yellow .. " MEM: " .. M.colors.reset .. 
                  string.format("%-41s", system_info.memory) .. M.colors.iceblue .. "║" .. M.colors.reset)
        end
        if system_info.time then
            print(M.colors.iceblue .. "║" .. M.colors.yellow .. " TIME: " .. M.colors.reset .. 
                  string.format("%-41s", system_info.time) .. M.colors.iceblue .. "║" .. M.colors.reset)
        end
        if system_info.cpu then
            print(M.colors.iceblue .. "║" .. M.colors.yellow .. " CPU: " .. M.colors.reset .. 
                  string.format("%-41s", system_info.cpu) .. M.colors.iceblue .. "║" .. M.colors.reset)
        end
    end
    
    print(M.colors.iceblue .. "╠══════════════════════════════════════════════════╣" .. M.colors.reset)
    
    -- Table header
    print(M.colors.iceblue .. "║" .. M.colors.reset .. 
          " NO  | PACKAGE                   | STATUS         " .. 
          M.colors.iceblue .. "║" .. M.colors.reset)
    
    print(M.colors.iceblue .. "╠══════════════════════════════════════════════════╣" .. M.colors.reset)
    
    -- Package rows
    for i, pkg in ipairs(config.packages) do
        local status = statuses[pkg] or "IDLE"
        local color = M.getStatusColor(status)
        
        -- Get display name
        local display_name = pkg
        if cached_users and cached_users[pkg] then
            local user = cached_users[pkg]
            if config.display.mask_username then
                user = user:sub(1, 3) .. "xxx" .. user:sub(-2)
            end
            display_name = user
        end
        
        -- Truncate if too long
        if #display_name > 23 then
            display_name = display_name:sub(1, 20) .. "..."
        end
        
        -- Format row
        local row = string.format(" %-3d | %-25s | ", i, display_name) .. 
                   color .. string.format("%-14s", status) .. M.colors.reset
        
        print(M.colors.iceblue .. "║" .. M.colors.reset .. row .. M.colors.iceblue .. " ║" .. M.colors.reset)
    end
    
    -- Footer
    print(M.colors.iceblue .. "╚══════════════════════════════════════════════════╝" .. M.colors.reset)
    print(M.colors.cyan .. " [CTRL+C] to Stop Monitor" .. M.colors.reset)
end

-- Get color based on status
function M.getStatusColor(status)
    if status == "ONLINE" then
        return M.colors.green
    elseif status == "LAUNCHING" then
        return M.colors.iceblue
    elseif status == "RESETTING" then
        return M.colors.red
    elseif status == "OPTIMIZING" then
        return M.colors.magenta
    elseif status:find("WAITING") or status:find("DELAY") then
        return M.colors.yellow
    elseif status == "ERROR" or status == "FAILED" then
        return M.colors.bright_red
    elseif status == "IDLE" then
        return M.colors.white
    else
        return M.colors.cyan
    end
end

-- Show loading animation
function M.showLoading(text, duration)
    local frames = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
    local start_time = os.time()
    local frame_idx = 1
    
    io.write(M.colors.cyan .. text .. " " .. M.colors.reset)
    
    while os.time() - start_time < duration do
        io.write("\r" .. M.colors.cyan .. text .. " " .. frames[frame_idx] .. M.colors.reset)
        io.flush()
        
        frame_idx = frame_idx + 1
        if frame_idx > #frames then frame_idx = 1 end
        
        -- Small delay
        local handle = io.popen("sleep 0.1")
        handle:close()
    end
    
    print("\r" .. M.colors.green .. text .. " ✓" .. M.colors.reset)
end

-- Create table display
function M.displayTable(headers, rows, title)
    if title then
        M.printSeparator(60, "═", M.colors.green)
        print("        " .. M.colors.cyan .. title .. M.colors.reset)
        M.printSeparator(60, "═", M.colors.green)
    end
    
    -- Calculate column widths
    local col_widths = {}
    for i, header in ipairs(headers) do
        col_widths[i] = #header
    end
    
    for _, row in ipairs(rows) do
        for i, cell in ipairs(row) do
            local cell_len = tostring(cell):len()
            if cell_len > col_widths[i] then
                col_widths[i] = cell_len
            end
        end
    end
    
    -- Add padding
    for i, _ in ipairs(col_widths) do
        col_widths[i] = col_widths[i] + 2
    end
    
    -- Print headers
    local header_line = M.colors.yellow
    for i, header in ipairs(headers) do
        header_line = header_line .. string.format("%-" .. col_widths[i] .. "s", header)
    end
    print(header_line .. M.colors.reset)
    
    -- Print separator
    local sep = ""
    for i, _ in ipairs(headers) do
        sep = sep .. string.rep("─", col_widths[i])
    end
    print(M.colors.cyan .. sep .. M.colors.reset)
    
    -- Print rows
    for _, row in ipairs(rows) do
        local row_line = ""
        for i, cell in ipairs(row) do
            row_line = row_line .. string.format("%-" .. col_widths[i] .. "s", tostring(cell))
        end
        print(row_line)
    end
end

-- Show notification
function M.showNotification(title, message, type)
    local color = M.colors.cyan
    local icon = "ℹ️"
    
    if type == "success" then
        color = M.colors.green
        icon = "✅"
    elseif type == "error" then
        color = M.colors.red
        icon = "❌"
    elseif type == "warning" then
        color = M.colors.yellow
        icon = "⚠️"
    elseif type == "info" then
        color = M.colors.iceblue
        icon = "💡"
    end
    
    print()
    M.printSeparator(50, "─", color)
    print(color .. "  " .. icon .. "  " .. title .. M.colors.reset)
    print("  " .. message)
    M.printSeparator(50, "─", color)
    print()
end

-- Create yes/no dialog
function M.yesNoDialog(question, default_yes)
    local options = default_yes and "(Y/n)" or "(y/N)"
    io.write(M.colors.yellow .. question .. " " .. options .. ": " .. M.colors.reset)
    local answer = io.read():lower()
    
    if answer == "" then
        return default_yes
    end
    
    return answer == "y" or answer == "yes"
end

-- Get screen resolution
function M.getScreenResolution()
    local width, height = 1080, 2400 -- Default values
    
    local handle = io.popen("su -c 'wm size 2>/dev/null'")
    if handle then
        local result = handle:read("*a")
        handle:close()
        
        if result then
            local w, h = result:match("Physical size: (%d+)x(%d+)")
            if w and h then
                width, height = tonumber(w), tonumber(h)
            end
        end
    end
    
    return width, height
end

-- Calculate window bounds
function M.calculateBounds(index, total_packages, screen_width, screen_height)
    -- Smart grid configuration
    local cols, rows
    local y_offset = 0
    
    if total_packages == 1 then
        -- Single account (Cinema mode)
        local margin_top = math.floor(screen_height * 0.15)
        local margin_bot = math.floor(screen_height * 0.05)
        return string.format("0,%d,%d,%d", margin_top, screen_width, screen_height - margin_bot)
        
    elseif total_packages == 2 then
        -- 2 accounts (Dual stack)
        cols = 1
        rows = 2
        y_offset = 120
        
    elseif total_packages <= 8 then
        -- 3-8 accounts (2 column grid)
        cols = 2
        rows = math.ceil(total_packages / 2)
        if rows < 2 then rows = 2 end
        y_offset = 80
        
    else
        -- 9+ accounts (3 column grid)
        cols = 3
        rows = math.ceil(total_packages / 3)
        y_offset = 60
    end
    
    -- Grid calculation
    local usable_height = screen_height - y_offset
    local cell_width = math.floor(screen_width / cols)
    local cell_height = math.floor(usable_height / rows)
    
    local i = index - 1
    local col = i % cols
    local row = math.floor(i / cols)
    
    local x1 = col * cell_width
    local y1 = y_offset + (row * cell_height)
    local x2 = x1 + cell_width
    local y2 = y1 + cell_height
    
    return string.format("%d,%d,%d,%d", x1, y1, x2, y2)
end

-- Get system information
function M.getSystemInfo()
    local info = {}
    
    -- Memory
    local mem_handle = io.popen("free -m 2>/dev/null | awk '/Mem:/ {printf \"%.1f/%.1f GB\", $3/1024, $2/1024}'")
    if mem_handle then
        info.memory = mem_handle:read("*a"):gsub("[\r\n]", "") or "N/A"
        mem_handle:close()
    end
    
    -- CPU (simplified)
    local cpu_handle = io.popen("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' 2>/dev/null")
    if cpu_handle then
        local cpu = cpu_handle:read("*a"):gsub("[\r\n]", "")
        if cpu and cpu ~= "" then
            info.cpu = cpu .. "%"
        end
        cpu_handle:close()
    end
    
    -- Time
    info.time = os.date("%H:%M:%S")
    
    return info
end

-- Format bytes to human readable
function M.formatBytes(bytes)
    local units = {"B", "KB", "MB", "GB", "TB"}
    local i = 1
    while bytes >= 1024 and i < #units do
        bytes = bytes / 1024
        i = i + 1
    end
    return string.format("%.2f %s", bytes, units[i])
end

-- Countdown timer
function M.countdown(seconds, message)
    message = message or "Starting in"
    
    for i = seconds, 1, -1 do
        io.write(string.format("\r%s %d seconds...", message, i))
        io.flush()
        
        local handle = io.popen("sleep 1")
        handle:close()
    end
    
    print("\r" .. string.rep(" ", 50)) -- Clear line
    print("\r" .. M.colors.green .. "Starting now!" .. M.colors.reset)
end

return M