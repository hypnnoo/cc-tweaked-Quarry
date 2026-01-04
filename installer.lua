-- installer.lua

local base = "https://raw.githubusercontent.com/hypnnoo/cc-tweaked-Quarry/main/"

local function download(path, dest)
    print("Downloading " .. path)
    if not shell.run("wget", base .. path, dest) then
        error("Failed to download " .. path)
    end
end

local function ensureDir(dir)
    if not fs.exists(dir) then fs.makeDir(dir) end
end

print("1) Dispatcher")
print("2) Miner Turtle")
print("3) Refueler Turtle")
write("> ")
local c = read()

if c == "1" then
    ensureDir("dispatcher")
    download("shared/protocol.lua", "protocol.lua")
    download("dispatcher/main.lua", "main.lua")
    download("dispatcher/config.lua", "config.lua")
    print("Run: main")

elseif c == "2" then
    ensureDir("turtle")
    download("shared/protocol.lua", "protocol.lua")
    download("turtle/worker.lua", "worker.lua")
    download("turtle/lane_miner.lua", "lane_miner.lua")
    download("turtle/inventory.lua", "inventory.lua")
    download("turtle/navigation.lua", "navigation.lua")
    print("Run: worker")

elseif c == "3" then
    ensureDir("turtle")
    download("turtle/refueler.lua", "refueler.lua")
    print("Run: refueler")
end

