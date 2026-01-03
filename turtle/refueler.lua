-- refueler.lua
-- Turtle that refuels all mining turtles using GPS

local protocol = require("protocol")

local modem = peripheral.find("modem")
modem.open(protocol.CHANNEL)

-- List of miner IDs and their GPS coordinates
local miners = {
    { id = "turtle1", x = 0, y = 64, z = 0 },
    { id = "turtle2", x = 4, y = 64, z = 0 },
    { id = "turtle3", x = 8, y = 64, z = 0 },
    { id = "turtle4", x = 12, y = 64, z = 0 },
}

-- Home chest location
local home = { x = -5, y = 64, z = 0 }

local function getPos()
    local x, y, z = gps.locate(2)
    if not x then error("GPS unavailable") end
    return x, y, z
end

local function goTo(target)
    local x, y, z = getPos()

    -- Move vertically first
    while y < target.y do turtle.up(); x,y,z = getPos() end
    while y > target.y do turtle.down(); x,y,z = getPos() end

    -- Move X
    while x < target.x do
        turtle.faceEast()
        turtle.forward()
        x,y,z = getPos()
    end
    while x > target.x do
        turtle.faceWest()
        turtle.forward()
        x,y,z = getPos()
    end

    -- Move Z
    while z < target.z do
        turtle.faceSouth()
        turtle.forward()
        x,y,z = getPos()
    end
    while z > target.z do
        turtle.faceNorth()
        turtle.forward()
        x,y,z = getPos()
    end
end

local function dumpInventory()
    for i = 1, 16 do
        turtle.select(i)
        turtle.drop()
    end
end

local function loadFuel()
    goTo(home)
    dumpInventory()
    turtle.suck(64 * 16) -- load full inventory of coal blocks
end

local function refuelMiner(miner)
    goTo(miner)

    -- Face miner
    turtle.turnLeft()
    turtle.turnLeft()

    -- Drop fuel into miner
    for i = 1, 16 do
        turtle.select(i)
        turtle.drop()
    end

    turtle.turnLeft()
    turtle.turnLeft()
end

while true do
    loadFuel()

    for _, miner in ipairs(miners) do
        refuelMiner(miner)
    end

    -- Return home and wait
    goTo(home)
    sleep(60)
end
