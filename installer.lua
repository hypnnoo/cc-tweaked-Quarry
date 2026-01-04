-- installer.lua
local base = "https://raw.githubusercontent.com/hypnnoo/cc-tweaked-Quarry/main/"

local function get(path, dest)
    print("Downloading", path)
    if not shell.run("wget", base .. path, dest) then
        error("Failed to download " .. path)
    end
end

local function dir(d)
    if not fs.exists(d) then fs.makeDir(d) end
end

print("1) Dispatcher")
print("2) Miner Turtle")
print("3) Refueler Turtle")
write("> ")
local c = read()

if c == "1" then
    dir("dispatcher")
    get("shared/protocol.lua", "protocol.lua")
    get("dispatcher/config.lua", "config.lua")
    get("dispatcher/main.lua", "main.lua")

elseif c == "2" then
    dir("turtle")
    get("shared/protocol.lua", "protocol.lua")
    get("turtle/worker.lua", "worker.lua")
    get("turtle/lane_miner.lua", "lane_miner.lua")
    get("turtle/inventory.lua", "inventory.lua")
    get("turtle/navigation.lua", "navigation.lua")

elseif c == "3" then
    dir("turtle")
    get("turtle/refueler.lua", "refueler.lua")
end

