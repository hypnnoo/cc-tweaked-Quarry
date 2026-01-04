-- turtle/lane_miner.lua
-- Mines a rectangular lane (width x depth) down "height" blocks.
-- Uses serpentine pattern; guaranteed no extra 16-block stretch.

local inventory = require("inventory")

local lane_miner = {}

local function ensureFuel()
    local level = turtle.getFuelLevel()
    if level == "unlimited" or level > 500 then return true end

    -- Try lava buckets first, then any other fuel
    for slot = 1, 16 do
        turtle.select(slot)
        local detail = turtle.getItemDetail()
        if detail and detail.name == "minecraft:lava_bucket" then
            turtle.refuel(1) -- consume lava, keep empty bucket
            level = turtle.getFuelLevel()
            if level > 500 then return true end
        elseif turtle.refuel(0) then
            turtle.refuel(64)
            level = turtle.getFuelLevel()
            if level > 500 then return true end
        end
    end

    return turtle.getFuelLevel() > 0
end

local function safeForward()
    ensureFuel()

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
    ensureFuel()

    while turtle.detectDown() do
        turtle.digDown()
        sleep(0.1)
    end
    while not turtle.down() do
        turtle.digDown()
        sleep(0.1)
    end
end

local function safeDigDown()
    -- clear the block below, but do not move
    while turtle.detectDown() do
        turtle.digDown()
        sleep(0.05)
    end
end

local function turn(right)
    if right then
        turtle.turnRight()
    else
        turtle.turnLeft()
    end
end

-- Move sideways one block to next row (used inside layer pattern)
local function moveToNextRow(goingForward)
    -- We are facing along the row direction.
    -- This will move us exactly 1 block sideways and flip our facing.
    if goingForward then
        -- turn right, forward, turn right
        turn(true)
        safeForward()
        turn(true)
    else
        -- turn left, forward, turn left
        turn(false)
        safeForward()
        turn(false)
    end
end

-- Mine one horizontal layer (width x depth), no vertical movement.
-- This stays within EXACTLY width × depth blocks.
local function mineLayer(width, depth, statusCallback, layerIndex, totalLayers)
    local goingForward = true

    for row = 1, depth do
        -- traverse width cells for this row; dig down at each cell
        for col = 1, width do
            ensureFuel()
            safeDigDown()  -- clear the block below this cell

            if inventory.isFull() then
                inventory.dumpToChest()
            end

            -- move forward if not at the last column in this row
            if col < width then
                safeForward()
            end
        end

        -- Progress callback per row
        if statusCallback and totalLayers and layerIndex then
            local totalRows = totalLayers * depth
            local doneRows  = (layerIndex - 1) * depth + row
            local pct       = math.floor((doneRows / totalRows) * 100)
            statusCallback(pct)
        end

        -- Move sideways to the next row (if there is one),
        -- flipping direction, but NOT extending the quarry.
        if row < depth then
            moveToNextRow(goingForward)
            goingForward = not goingForward
        end
    end
end

-- Public entry: called as miner.mine(job, callback) from worker.lua
-- job: { jobId, xOffset, width, depth, height }
function lane_miner.mine(job, statusCallback)
    local width  = job.width
    local depth  = job.depth
    local height = job.height or 10

    -- 1. Move horizontally to lane start: xOffset blocks along X.
    -- Assumes turtles are lined up along X, facing +Z into the quarry.
    -- We step sideways in +X, then face back to +Z.
    if job.xOffset and job.xOffset > 0 then
        turtle.turnRight()  -- +Z -> +X
        for _ = 1, job.xOffset do
            safeForward()
            if inventory.isFull() then
                inventory.dumpToChest()
            end
        end
        turtle.turnLeft()   -- +X -> +Z
    end

    -- 2. Mine down layer by layer. Each layer is EXACTLY width × depth.
    local layersMined = 0
    local totalLayers = height

    while layersMined < totalLayers do
        mineLayer(width, depth, statusCallback, layersMined + 1, totalLayers)
        layersMined = layersMined + 1

        if layersMined < totalLayers then
            safeDown()  -- go down exactly 1, do NOT move forward/back
        end
    end

    if statusCallback then
        statusCallback(100)
    end
end

return lane_miner

