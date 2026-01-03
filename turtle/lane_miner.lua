-- turtle/lane_miner.lua
-- Mines a rectangular lane (width x depth) down "height" blocks.

local inventory = require("inventory")

local lane_miner = {}

local function ensureFuel()
    if turtle.getFuelLevel() == "unlimited" then return true end
    if turtle.getFuelLevel() < 200 then
        -- try to refuel from inventory
        for slot = 1, 16 do
            turtle.select(slot)
            if turtle.refuel(0) then
                turtle.refuel(64)
                if turtle.getFuelLevel() > 1000 then break end
            end
        end
    end
    return turtle.getFuelLevel() > 0
end

local function safeForward()
    while turtle.detect() do
        turtle.dig()
        sleep(0.1)
    end
    while not turtle.forward() do
        turtle.dig()
        sleep(0.1)
    end
end

local function safeDown()
    while turtle.detectDown() do
        turtle.digDown()
        sleep(0.1)
    end
    while not turtle.down() do
        turtle.digDown()
        sleep(0.1)
    end
end

local function turn(right)
    if right then turtle.turnRight() else turtle.turnLeft() end
end

-- Move forward n blocks, digging as needed
local function moveForwardN(n)
    for _ = 1, n do
        ensureFuel()
        safeForward()
        if inventory.isFull() then
            inventory.dumpToChest()
        end
    end
end

-- Move sideways one block to next row (used inside layer pattern)
local function moveToNextRow(goingForward)
    if goingForward then
        turn(true)
        ensureFuel()
        safeForward()
        turn(true)
    else
        turn(false)
        ensureFuel()
        safeForward()
        turn(false)
    end
    if inventory.isFull() then
        inventory.dumpToChest()
    end
end

-- Mine one horizontal layer (width x depth)
local function mineLayer(width, depth, statusCallback, layerIndex, totalLayers)
    local goingForward = true

    for row = 1, depth do
        for col = 1, width - 1 do
            ensureFuel()
            safeForward()
            if inventory.isFull() then
                inventory.dumpToChest()
            end
        end

        if statusCallback and totalLayers and layerIndex then
            local total = totalLayers * depth
            local done = (layerIndex - 1) * depth + row
            local pct = math.floor((done / total) * 100)
            statusCallback(pct)
        end

        if row ~= depth then
            moveToNextRow(goingForward)
            goingForward = not goingForward
        end
    end
end

function lane_miner.mineLane(job, statusCallback)
    -- job: {jobId, xOffset, width, depth, height}

    local width = job.width
    local depth = job.depth
    local height = job.height or 10

    -- 1. Move horizontally to lane start: xOffset blocks along X
    -- Assumes turtles are lined up along X, facing +Z.
    for _ = 1, job.xOffset do
        ensureFuel()
        safeForward()
        if inventory.isFull() then
            inventory.dumpToChest()
        end
    end

    -- 2. Mine down layer by layer
    local layersMined = 0
    local totalLayers = height

    while layersMined < totalLayers do
        mineLayer(width, depth, statusCallback, layersMined + 1, totalLayers)
        layersMined = layersMined + 1

        if layersMined < totalLayers then
            ensureFuel()
            safeDown()
        end
    end

    if statusCallback then
        statusCallback(100)
    end
end

return lane_miner
