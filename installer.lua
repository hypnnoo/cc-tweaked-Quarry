-- installer.lua
-- One-command installer for the quarry fleet

local base = "https://raw.githubusercontent.com/hypnnoo/cc-tweaked-Quarry/main/"

local function download(path, dest)
    print("Downloading " .. path .. "...")
    local url = base .. path
    local ok = shell.run("wget", url, dest)
    if not ok then
        error("Failed to download " .. path)
    end
end

local function ensureDir(dir)
    if not fs.exists(dir) then
        fs.makeDir(dir)
    end
end

print("Select install target:")
print("  1) Dispatcher computer")
print("  2) Miner turtle")
print("  3) Refueler turtle")
write("> ")
local choice = read()

if choice == "1" then
    -- Dispatcher
    download("shared/protocol.lua", "protocol.lua")
    download("dispatcher/config.lua", "config.lua")
    download("dispatcher/main.lua", "main.lua")
    print("Dispatcher installed. Run 'main' to start.")

elseif choice == "2" then
    -- Miner turtle
    download("shared/protocol.lua", "protocol.lua")
    download("turtle/worker.lua", "worker.lua")
    download("turtle/lane_miner.lua", "lane_miner.lua")
    download("turtle/inventory.lua", "inventory.lua")
    download("turtle/navigation.lua", "navigation.lua")
    print("Miner installed. Run 'worker' to start.")

elseif choice == "3" then
    -- Refueler turtle
    download("shared/protocol.lua", "protocol.lua")
    download("turtle/refueler.lua", "refueler.lua")
    print("Refueler installed. Run 'refueler' to start.")

else
    print("Invalid choice.")
end

