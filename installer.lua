-- installer.lua
-- One-command installer for the quarry fleet

local base = "https://raw.githubusercontent.com/hypnnoo/cc-tweaked-Quarry/main/"

local function download(path, dest)
    print("Downloading " .. path .. "...")
    local url = base .. path
    local ok = shell.run("wget", url, dest)
    if not ok then
        print("Failed to download " .. path)
    end
end

local function ensureDir(dir)
    if not fs.exists(dir) then
        fs.makeDir(dir)
    end
end

print("Install type:")
print("1) Dispatcher")
print("2) Miner Turtle")
print("3) Refueler Turtle")
write("> ")
local choice = read()

if choice == "1" then
    print("Installing dispatcher...")

    ensureDir("shared")
    ensureDir("dispatcher")

    download("shared/protocol.lua", "protocol.lua")
    download("dispatcher/main.lua", "main.lua")
    download("dispatcher/config.lua", "config.lua")

    print("Dispatcher install complete.")
    print("Run with: main")

elseif choice == "2" then
    print("Installing miner turtle...")

    ensureDir("shared")
    ensureDir("turtle")

    download("shared/protocol.lua", "protocol.lua")
    download("turtle/worker.lua", "worker.lua")
    download("turtle/lane_miner.lua", "lane_miner.lua")
    download("turtle/inventory.lua", "inventory.lua")
    download("turtle/navigation.lua", "navigation.lua")

    print("Miner turtle install complete.")
    print("Run with: worker")

elseif choice == "3" then
    print("Installing refueler turtle...")

    ensureDir("turtle")
    download("turtle/refueler.lua", "refueler.lua")

    print("Refueler install complete.")
    print("Run with: refueler")

else
    print("Invalid choice.")
end
