-- webhook.lua
-- Discord Webhook Integration Module for DIVINETOOLS

local config = require("modules.config")
local ui = require("modules.ui")
local utils = require("modules.utils")
local socket = require("socket")
local http = require("socket.http")
local ltn12 = require("ltn12")
local cjson = require("cjson")

local M = {}

-- Webhook cache and state
local message_cache = {}
local last_sent_times = {}
local webhook_queue = {}
local is_sending = false

-- Colors for Discord embeds (decimal)
local DISCORD_COLORS = {
    SUCCESS = 65280,      -- Green
    ERROR = 16711680,     -- Red
    WARNING = 16776960,   -- Yellow
    INFO = 3447003,       -- Blue
    MONITOR = 7419530,    -- Teal
    OPTIMIZATION = 10181046, -- Purple
    SYSTEM = 15844367,    -- Gold
    DIVINE = 15277667     -- Pink
}

-- Validate webhook URL
function M.validateWebhookURL(url)
    if not url or url == "" then
        return false, "URL is empty"
    end
    
    -- Discord webhook pattern
    local pattern = "^https://discord%.com/api/webhooks/%d+/[%w%-_]+$"
    if not url:match(pattern) then
        return false, "Invalid Discord webhook URL format"
    end
    
    -- Test connection
    local success, status = M.testWebhook(url)
    if not success then
        return false, "Webhook test failed: " .. (status or "unknown error")
    end
    
    return true, "Valid webhook URL"
end

-- Test webhook connection
function M.testWebhook(url)
    local test_payload = {
        content = nil,
        embeds = {{
            title = "✅ DIVINETOOLS Webhook Test",
            description = "Webhook connection test successful!",
            color = DISCORD_COLORS.SUCCESS,
            timestamp = M.getISOTimestamp(),
            footer = {
                text = "DIVINETOOLS v2.0",
                icon_url = "https://i.imgur.com/fKL31aD.png"
            },
            fields = {
                {
                    name = "🕒 Time",
                    value = os.date("%Y-%m-%d %H:%M:%S"),
                    inline = true
                },
                {
                    name = "📱 Device",
                    value = utils.getDeviceModel() or "Unknown",
                    inline = true
                },
                {
                    name = "🤖 Android",
                    value = utils.getAndroidVersion() or "Unknown",
                    inline = true
                }
            }
        }}
    }
    
    local success, status = M.sendWebhook(url, test_payload)
    return success, status
end

-- Get ISO timestamp for Discord
function M.getISOTimestamp()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

-- Format package status for Discord
function M.formatPackageStatus(statuses, packages, cached_users, config_data)
    local fields = {}
    local online_count = 0
    local total_count = #packages
    
    for i, pkg in ipairs(packages) do
        local status = statuses[pkg] or "UNKNOWN"
        local user = cached_users and cached_users[pkg]
        local display_user = user or "Not logged in"
        
        if config_data and config_data.display.mask_username and user then
            display_user = user:sub(1, 3) .. "xxx" .. user:sub(-2)
        end
        
        local emoji = "🟡"  -- Yellow circle (unknown)
        if status == "ONLINE" or status == "RUNNING" then
            emoji = "🟢"    -- Green circle
            online_count = online_count + 1
        elseif status:match("CRASH") or status:match("FAIL") then
            emoji = "🔴"    -- Red circle
        elseif status:match("LAUNCH") or status:match("START") then
            emoji = "🟠"    -- Orange circle
        elseif status:match("STOP") or status:match("IDLE") then
            emoji = "⚫"    -- Black circle
        end
        
        local display_name = pkg:match("[^%.]+$") or pkg
        if #display_name > 15 then
            display_name = display_name:sub(1, 12) .. "..."
        end
        
        table.insert(fields, {
            name = emoji .. " " .. display_name,
            value = string.format("**User:** %s\n**Status:** %s", 
                    display_user, status),
            inline = true
        })
        
        -- Limit fields to 25 (Discord limit)
        if #fields >= 25 then
            table.insert(fields, {
                name = "⚠️ Additional packages",
                value = string.format("%d more packages not shown", total_count - i),
                inline = false
            })
            break
        end
    end
    
    return fields, online_count, total_count
end

-- Create monitoring status embed
function M.createStatusEmbed(statuses, packages, cached_users, config_data, system_info)
    local fields, online_count, total_count = M.formatPackageStatus(
        statuses, packages, cached_users, config_data
    )
    
    local title = "📊 DIVINETOOLS Monitoring Status"
    local description = string.format("**%d/%d** packages online", online_count, total_count)
    
    local color = DISCORD_COLORS.SUCCESS
    if online_count == 0 then
        color = DISCORD_COLORS.ERROR
        description = "❌ **ALL PACKAGES OFFLINE**"
    elseif online_count < total_count then
        color = DISCORD_COLORS.WARNING
    end
    
    -- Add system info fields
    if system_info then
        table.insert(fields, 1, {
            name = "🖥️ System Info",
            value = string.format("**Memory:** %s\n**Time:** %s", 
                    system_info.memory or "N/A", 
                    system_info.time or "N/A"),
            inline = false
        })
    end
    
    local embed = {
        title = title,
        description = description,
        color = color,
        timestamp = M.getISOTimestamp(),
        footer = {
            text = "DIVINETOOLS v2.0 | " .. os.date("%H:%M:%S"),
            icon_url = "https://i.imgur.com/fKL31aD.png"
        },
        fields = fields
    }
    
    return embed
end

-- Create startup notification embed
function M.createStartupEmbed(config_data, package_count)
    local embed = {
        title = "🚀 DIVINETOOLS Monitoring Started",
        description = string.format("Monitoring **%d** package(s) has started", package_count),
        color = DISCORD_COLORS.MONITOR,
        timestamp = M.getISOTimestamp(),
        footer = {
            text = "DIVINETOOLS v2.0",
            icon_url = "https://i.imgur.com/fKL31aD.png"
        },
        fields = {
            {
                name = "📦 Packages",
                value = package_count,
                inline = true
            },
            {
                name = "📱 Device",
                value = utils.getDeviceModel() or "Unknown",
                inline = true
            },
            {
                name = "🤖 Android",
                value = utils.getAndroidVersion() or "Unknown",
                inline = true
            },
            {
                name = "🕒 Started At",
                value = os.date("%H:%M:%S"),
                inline = false
            }
        }
    }
    
    return embed
end

-- Create shutdown notification embed
function M.createShutdownEmbed(runtime, statistics)
    local embed = {
        title = "🛑 DIVINETOOLS Monitoring Stopped",
        description = "Monitoring has been stopped",
        color = DISCORD_COLORS.SYSTEM,
        timestamp = M.getISOTimestamp(),
        footer = {
            text = "DIVINETOOLS v2.0",
            icon_url = "https://i.imgur.com/fKL31aD.png"
        }
    }
    
    if statistics then
        embed.fields = {
            {
                name = "⏱️ Runtime",
                value = utils.formatTime(runtime),
                inline = true
            },
            {
                name = "📦 Packages",
                value = statistics.packages or 0,
                inline = true
            },
            {
                name = "🟢 Online",
                value = statistics.running or 0,
                inline = true
            },
            {
                name = "🔴 Crashed",
                value = statistics.crashed or 0,
                inline = true
            },
            {
                name = "⚫ Stopped",
                value = statistics.stopped or 0,
                inline = true
            }
        }
    end
    
    return embed
end

-- Create error notification embed
function M.createErrorEmbed(error_message, context)
    local embed = {
        title = "❌ DIVINETOOLS Error",
        description = "An error occurred during monitoring",
        color = DISCORD_COLORS.ERROR,
        timestamp = M.getISOTimestamp(),
        footer = {
            text = "DIVINETOOLS v2.0",
            icon_url = "https://i.imgur.com/fKL31aD.png"
        },
        fields = {
            {
                name = "Error Message",
                value = "```" .. (error_message or "Unknown error") .. "```",
                inline = false
            }
        }
    }
    
    if context then
        table.insert(embed.fields, {
            name = "Context",
            value = context,
            inline = false
        })
    end
    
    return embed
end

-- Create optimization notification embed
function M.createOptimizationEmbed(preset, packages, results)
    local embed = {
        title = "🔧 DIVINETOOLS Optimization",
        description = string.format("**%s** applied to **%d** package(s)", 
                preset.name or "Optimization", #packages),
        color = DISCORD_COLORS.OPTIMIZATION,
        timestamp = M.getISOTimestamp(),
        footer = {
            text = "DIVINETOOLS v2.0",
            icon_url = "https://i.imgur.com/fKL31aD.png"
        },
        fields = {}
    }
    
    if results and #results > 0 then
        for _, result in ipairs(results) do
            if type(result) == "table" and result.name then
                table.insert(embed.fields, {
                    name = "✅ " .. result.name,
                    value = result.result or "Completed",
                    inline = true
                })
            elseif type(result) == "string" then
                table.insert(embed.fields, {
                    name = "✅ Action",
                    value = result,
                    inline = true
                })
            end
        end
    end
    
    return embed
end

-- Create package event embed
function M.createPackageEventEmbed(pkg, event, details, user)
    local events = {
        LAUNCH = { emoji = "🚀", color = DISCORD_COLORS.MONITOR, title = "Package Launched" },
        STOP = { emoji = "🛑", color = DISCORD_COLORS.SYSTEM, title = "Package Stopped" },
        CRASH = { emoji = "💥", color = DISCORD_COLORS.ERROR, title = "Package Crashed" },
        RESTART = { emoji = "🔄", color = DISCORD_COLORS.WARNING, title = "Package Restarted" },
        OPTIMIZE = { emoji = "🔧", color = DISCORD_COLORS.OPTIMIZATION, title = "Package Optimized" }
    }
    
    local event_info = events[event] or { emoji = "ℹ️", color = DISCORD_COLORS.INFO, title = "Package Event" }
    
    local embed = {
        title = event_info.emoji .. " " .. event_info.title,
        description = string.format("**Package:** `%s`\n**User:** %s", 
                pkg, user or "Unknown"),
        color = event_info.color,
        timestamp = M.getISOTimestamp(),
        footer = {
            text = "DIVINETOOLS v2.0",
            icon_url = "https://i.imgur.com/fKL31aD.png"
        }
    }
    
    if details then
        embed.fields = {
            {
                name = "📝 Details",
                value = details,
                inline = false
            }
        }
    end
    
    return embed
end

-- Send webhook with retry logic
function M.sendWebhook(url, payload, mode, message_id)
    if not url or url == "" then
        return false, "Webhook URL not provided"
    end
    
    local headers = {
        ["Content-Type"] = "application/json",
        ["User-Agent"] = "DIVINETOOLS/2.0"
    }
    
    local method = "POST"
    local full_url = url
    
    -- Handle edit mode
    if mode == "edit" and message_id then
        method = "PATCH"
        full_url = url .. "/messages/" .. message_id
    elseif mode == "delete" and message_id then
        method = "DELETE"
        full_url = url .. "/messages/" .. message_id
        payload = nil
    end
    
    -- Convert payload to JSON
    local json_payload
    if payload then
        local success, json = pcall(cjson.encode, payload)
        if not success then
            return false, "Failed to encode JSON: " .. json
        end
        json_payload = json
    end
    
    -- Send request with retry
    local max_retries = 3
    local retry_delay = 1
    
    for attempt = 1, max_retries do
        local response_body = {}
        local request = {
            url = full_url,
            method = method,
            headers = headers,
            source = json_payload and ltn12.source.string(json_payload) or nil,
            sink = ltn12.sink.table(response_body)
        }
        
        local success, status_code, response_headers = http.request(request)
        
        if success and status_code == 200 or status_code == 204 then
            local response = table.concat(response_body)
            
            -- Parse response for message ID if new message
            if mode == "new" and response and response ~= "" then
                local ok, msg = pcall(cjson.decode, response)
                if ok and msg.id then
                    return true, msg.id
                end
            end
            
            return true, "Success"
        elseif status_code == 429 then
            -- Rate limited, get retry delay
            local retry_after = 1
            if response_headers and response_headers["retry-after"] then
                retry_after = tonumber(response_headers["retry-after"]) or 1
            end
            
            if attempt < max_retries then
                print(ui.colors.yellow .. string.format(
                    "[!] Rate limited. Retrying in %d seconds... (attempt %d/%d)", 
                    retry_after, attempt, max_retries) .. ui.colors.reset)
                socket.sleep(retry_after)
            end
        else
            local error_msg = string.format("HTTP %d", status_code or 0)
            if attempt < max_retries then
                print(ui.colors.yellow .. string.format(
                    "[!] Webhook failed: %s. Retrying in %d seconds... (attempt %d/%d)", 
                    error_msg, retry_delay, attempt, max_retries) .. ui.colors.reset)
                socket.sleep(retry_delay)
                retry_delay = retry_delay * 2  -- Exponential backoff
            else
                return false, error_msg
            end
        end
    end
    
    return false, "Max retries exceeded"
end

-- Queue webhook for sending
function M.queueWebhook(url, payload, mode, message_id, priority)
    table.insert(webhook_queue, {
        url = url,
        payload = payload,
        mode = mode or "new",
        message_id = message_id,
        priority = priority or 5,
        timestamp = os.time()
    })
    
    -- Sort by priority (lower = higher priority)
    table.sort(webhook_queue, function(a, b)
        if a.priority == b.priority then
            return a.timestamp < b.timestamp
        end
        return a.priority < b.priority
    end)
    
    -- Start sender if not running
    if not is_sending then
        M.processQueue()
    end
    
    return #webhook_queue
end

-- Process webhook queue
function M.processQueue()
    if is_sending or #webhook_queue == 0 then
        return
    end
    
    is_sending = true
    
    -- Run in background
    local function sender()
        while #webhook_queue > 0 do
            local item = table.remove(webhook_queue, 1)
            
            local success, result = M.sendWebhook(
                item.url, 
                item.payload, 
                item.mode, 
                item.message_id
            )
            
            if success and item.mode == "new" and result ~= "Success" then
                -- Store message ID for edit mode
                message_cache[item.url] = result
            elseif not success then
                print(ui.colors.red .. "[!] Failed to send webhook: " .. result .. ui.colors.reset)
                
                -- Retry failed items (lower priority)
                if item.priority < 10 then  -- Don't retry low priority items too much
                    item.priority = item.priority + 1
                    table.insert(webhook_queue, item)
                end
            end
            
            -- Small delay between sends
            socket.sleep(0.5)
        end
        
        is_sending = false
    end
    
    -- Start sender in background
    local thread = coroutine.create(sender)
    coroutine.resume(thread)
end

-- Send status update
function M.sendStatusUpdate(statuses, packages, cached_users, config_data, system_info)
    if not config_data.webhook.enabled or not config_data.webhook.url then
        return false, "Webhook not enabled"
    end
    
    local url = config_data.webhook.url
    
    -- Create embed
    local embed = M.createStatusEmbed(statuses, packages, cached_users, config_data, system_info)
    
    -- Prepare payload
    local payload = {
        embeds = {embed},
        username = "DIVINETOOLS Monitor",
        avatar_url = "https://i.imgur.com/fKL31aD.png"
    }
    
    -- Add @everyone mention if enabled
    if config_data.webhook.tag_everyone then
        payload.content = "@everyone"
    end
    
    -- Determine mode
    local mode = config_data.webhook.mode or "new"
    local message_id = config_data.webhook.message_id
    
    if mode == "edit" and message_id then
        return M.queueWebhook(url, payload, "edit", message_id, 3)
    else
        -- Send new message
        local success, result = M.sendWebhook(url, payload, "new")
        
        if success and result ~= "Success" then
            -- Update config with new message ID
            config_data.webhook.message_id = result
            config.save(config_data)
        end
        
        return success, result
    end
end

-- Send startup notification
function M.sendStartupNotification(config_data)
    if not config_data.webhook.enabled or not config_data.webhook.url then
        return false
    end
    
    local embed = M.createStartupEmbed(config_data, #config_data.packages)
    
    local payload = {
        embeds = {embed},
        username = "DIVINETOOLS Monitor",
        avatar_url = "https://i.imgur.com/fKL31aD.png"
    }
    
    if config_data.webhook.tag_everyone then
        payload.content = "@everyone"
    end
    
    return M.queueWebhook(config_data.webhook.url, payload, "new", nil, 1)
end

-- Send shutdown notification
function M.sendShutdownNotification(config_data, runtime, statistics)
    if not config_data.webhook.enabled or not config_data.webhook.url then
        return false
    end
    
    local embed = M.createShutdownEmbed(runtime, statistics)
    
    local payload = {
        embeds = {embed},
        username = "DIVINETOOLS Monitor",
        avatar_url = "https://i.imgur.com/fKL31aD.png"
    }
    
    return M.queueWebhook(config_data.webhook.url, payload, "new", nil, 1)
end

-- Send error notification
function M.sendErrorNotification(config_data, error_message, context)
    if not config_data.webhook.enabled or not config_data.webhook.url then
        return false
    end
    
    local embed = M.createErrorEmbed(error_message, context)
    
    local payload = {
        embeds = {embed},
        username = "DIVINETOOLS Monitor",
        avatar_url = "https://i.imgur.com/fKL31aD.png",
        content = config_data.webhook.tag_everyone and "@everyone" or nil
    }
    
    return M.queueWebhook(config_data.webhook.url, payload, "new", nil, 1)
end

-- Send optimization notification
function M.sendOptimizationNotification(config_data, preset, packages, results)
    if not config_data.webhook.enabled or not config_data.webhook.url then
        return false
    end
    
    local embed = M.createOptimizationEmbed(preset, packages, results)
    
    local payload = {
        embeds = {embed},
        username = "DIVINETOOLS Optimizer",
        avatar_url = "https://i.imgur.com/fKL31aD.png"
    }
    
    return M.queueWebhook(config_data.webhook.url, payload, "new", nil, 2)
end

-- Send package event notification
function M.sendPackageEvent(config_data, pkg, event, details, user)
    if not config_data.webhook.enabled or not config_data.webhook.url then
        return false
    end
    
    -- Check if we should send this event (avoid spam)
    local now = os.time()
    local last_sent = last_sent_times[pkg] or 0
    
    -- Rate limiting: max 1 event per 30 seconds per package
    if now - last_sent < 30 and event ~= "CRASH" then
        return false, "Rate limited"
    end
    
    last_sent_times[pkg] = now
    
    local embed = M.createPackageEventEmbed(pkg, event, details, user)
    
    local payload = {
        embeds = {embed},
        username = "DIVINETOOLS Monitor",
        avatar_url = "https://i.imgur.com/fKL31aD.png"
    }
    
    -- Only tag for crashes
    if event == "CRASH" and config_data.webhook.tag_everyone then
        payload.content = "@everyone"
    end
    
    return M.queueWebhook(config_data.webhook.url, payload, "new", nil, 2)
end

-- Periodic status updates
function M.startPeriodicUpdates(config_data, update_function, interval)
    interval = interval or (config_data.webhook.interval or 5) * 60  -- Convert to seconds
    
    if interval < 300 then  -- Minimum 5 minutes
        interval = 300
    end
    
    local update_thread = coroutine.create(function()
        while true do
            socket.sleep(interval)
            
            if config_data.webhook.enabled then
                local success, err = pcall(update_function)
                if not success then
                    print(ui.colors.red .. "[!] Periodic update failed: " .. err .. ui.colors.reset)
                end
            end
        end
    end)
    
    coroutine.resume(update_thread)
    return update_thread
end

-- Test webhook configuration
function M.testConfiguration(config_data)
    if not config_data.webhook.enabled then
        ui.showMessage("Webhook is not enabled in configuration", "warning")
        return false
    end
    
    if not config_data.webhook.url or config_data.webhook.url == "" then
        ui.showMessage("Webhook URL is not set", "error")
        return false
    end
    
    print(ui.colors.cyan .. "[*] Testing webhook configuration..." .. ui.colors.reset)
    
    local valid, message = M.validateWebhookURL(config_data.webhook.url)
    
    if valid then
        ui.showMessage("Webhook test successful!", "success")
        
        -- Send a test notification
        M.sendStartupNotification(config_data)
        
        return true
    else
        ui.showMessage("Webhook test failed: " .. message, "error")
        return false
    end
end

-- Clear webhook message
function M.clearWebhookMessage(config_data)
    if not config_data.webhook.enabled or not config_data.webhook.message_id then
        return false
    end
    
    local url = config_data.webhook.url
    local message_id = config_data.webhook.message_id
    
    local success, result = M.sendWebhook(url, nil, "delete", message_id)
    
    if success then
        config_data.webhook.message_id = ""
        config.save(config_data)
        ui.showMessage("Webhook message cleared", "success")
    else
        ui.showMessage("Failed to clear webhook message: " .. result, "error")
    end
    
    return success
end

-- Get webhook statistics
function M.getStatistics()
    return {
        queue_size = #webhook_queue,
        is_sending = is_sending,
        message_cache_size = #M.tableKeys(message_cache),
        last_sent_count = #M.tableKeys(last_sent_times)
    }
end

-- Initialize webhook module
function M.initialize()
    print(ui.colors.cyan .. "[*] Initializing webhook module..." .. ui.colors.reset)
    
    -- Clear old cache
    message_cache = {}
    last_sent_times = {}
    webhook_queue = {}
    
    -- Test connection if enabled
    local config_data = config.load()
    if config_data.webhook.enabled and config_data.webhook.url ~= "" then
        local valid = M.testConfiguration(config_data)
        if not valid then
            ui.showMessage("Webhook configuration is invalid. Disabling...", "warning")
            config_data.webhook.enabled = false
            config.save(config_data)
        end
    end
    
    return true
end

-- Helper function to get table keys (duplicate from utils, but for completeness)
function M.tableKeys(tbl)
    local keys = {}
    for k, _ in pairs(tbl) do
        table.insert(keys, k)
    end
    return keys
end

return M