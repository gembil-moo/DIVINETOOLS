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
    return config
end

local function saveConfig(config)
    local file = io.open(CONFIG_PATH, "w")
    if file then
        -- Gunakan cjson untuk menyimpan dengan format yang rapi
        file:write(cjson.encode_pretty(config))
        file:close()
    else
        print(red.."Error: Could not save config."..reset)
    end
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
        print("  [7] Back to Main Menu")

        border()
        io.write(yellow.."Select option (1-7): "..reset)
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
                        print("  ["..i.."] " .. pkg)
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
                    -- Implementasi Remove Package bisa ditambahkan di sini
                    print(green.."Feature coming soon..."..reset)
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
            print(green.."Configuring Webhook..."..reset)

        elseif c == "5" then
            print(green.."Setting Delay Launch..."..reset)

        elseif c == "6" then
            print(green.."Setting Relaunch Loop Delay..."..reset)

        elseif c == "7" then
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
        print(green.."Running first configuration..."..reset)

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