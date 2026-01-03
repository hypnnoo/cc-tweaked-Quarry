-- turtle/refueler.lua
-- Turtle that refuels all mining turtles using coal blocks.
-- Assumes all targets and home are on (approximately) same Y.

local function getPos()
    local x, y, z = gps.locate(3)
    if not x then error("GPS unavailable") end
    return x, y, z
end

-- simple heading tracking: 0 = +Z, 1 = -X, 2 = -Z, 3 = +X
local heading = 0

local function turnLeft()
    turtle.turnLeft()
    heading = (heading + 1) % 4
end

local function turnRight()
    turtle.turnRight()
    heading = (heading + 3) % 4
end

local function face(dir)
    while heading ~= dir do
        turnRight()
    end
end

local function forward()
    while not turtle.forward() do
        turtle.dig()
        sleep(0.1)
    end
end

local function goTo(target)
    local x, y, z = getPos()

    -- First: move vertically if needed
    while y < target.y do
        while turtle.detectUp() do turtle.digUp() end
        turtle.up()
        x, y, z = getPos()
    end
    while y > target.y do
        while turtle.detectDown() do turtle.digDown() end
        turtle.down()
        x, y, z = getPos()
    end

    -- Move in X
    x, y, z = getPos()
    if target.x > x then
        face(3) -- +X
        while x < target.x do
            forward()
            x, y, z = getPos()
        end
    elseif target.x < x then
        face(1) -- -X
        while x > target.x do
            forward()
            x, y, z = getPos()
        end
    end

    -- Move in Z
    x, y, z = getPos()
    if target.z > z then
        face(0) -- +Z
        while z < target.z do
            forward()
            x, y, z = getPos()
        end
    elseif target.z < z then
        face(2) -- -Z
        while z > target.z do
            forward()
            x, y, z = getPos()
        end
    end
end

local function dumpInventory()
    for i = 1, 16 do
        turtle.select(i)
        turtle.drop()
    end
end

local function loadFuel()
    -- assume we start at home facing +Z (heading 0) and there's a chest in front
    dumpInventory()
    for i = 1, 16 do
        turtle.select(i)
        turtle.suck(64)
    end
end

-- EDIT THESE TO MATCH YOUR WORLD:
local miners = {
    { x = 0,  y = 64, z = 0 },  -- miner 1 surface position
    { x = 4,  y = 64, z = 0 },  -- miner 2
    { x = 8,  y = 64, z = 0 },  -- miner 3
    { x = 12, y = 64, z = 0 },  -- miner 4
}

local home = { x = -5, y = 64, z = 0 } -- fuel chest position

-- Initialize heading assumption: face +Z
heading = 0

while true do
    -- go home and load fuel
    goTo(home)
    face(0) -- +Z
    loadFuel()

    -- visit each miner and dump fuel into chest behind them (or directly at them)
    for _, miner in ipairs(miners) do
        goTo(miner)
        -- face miner and drop fuel forward
        face(0) -- adjust if your layout is different
        for i = 1, 16 do
            turtle.select(i)
            turtle.drop()
        end
    end

    -- return home and wait
    goTo(home)
    face(0)
    sleep(240) -- wait 240 seconds before next cycle
end
