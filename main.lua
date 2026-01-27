-- ===== WARNA ANSI =====
local iceblue = "\27[38;5;51m"
local green   = "\27[38;5;46m"
local red     = "\27[31m"
local yellow  = "\27[33m"
local reset   = "\27[0m"

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

-- ===== CONFIG HELPER (LUA FORMAT) =====
local CONFIG_PATH = "config/config.lua"

local function loadConfig()
    -- Coba load file config.lua
    local chunk, err = loadfile(CONFIG_PATH)
    if chunk then
        -- Jika berhasil, jalankan chunk untuk mendapatkan tabel
        local success, result = pcall(chunk)
        if success and type(result) == "table" then
            return result
        end
    end
    -- Default jika file tidak ada atau error
    return {packages = {}}
end

local function saveConfig(config)
    local file = io.open(CONFIG_PATH, "w")
    if file then
        file:write("return {\n")
        file:write("    packages = {\n")
        if config.packages then
            for _, pkg in ipairs(config.packages) do
                file:write(string.format("        %q,\n", pkg))
            end
        end
        file:write("    }\n")
        file:write("}\n")
        file:close()
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
                        
                        local selected_indices = {}
                        if input == "" then
                            for i = 1, #scanned_packages do table.insert(selected_indices, i) end
                        else
                            for str in string.gmatch(input, "([^,]+)") do
                                local n = tonumber(str)
                                if n and scanned_packages[n] then table.insert(selected_indices, n) end
                            end
                        end

                        if #selected_indices > 0 then
                            local config = loadConfig()
                            local exists = {}
                            for _, p in ipairs(config.packages) do exists[p] = true end
                            
                            local added_count = 0
                            for _, idx in ipairs(selected_indices) do
                                if not exists[scanned_packages[idx]] then
                                    table.insert(config.packages, scanned_packages[idx])
                                    added_count = added_count + 1
                                end
                            end
                            saveConfig(config)
                            print(green.."Saved "..added_count.." new package(s) to config/config.lua!"..reset)
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
            print(green.."Opening Private Server List..."..reset)

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