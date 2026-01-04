-- turtle/lane_miner.lua
-- Simple, strictly bounded 3D quarry miner: width × depth × height
-- Assumptions:
--  - Turtle is placed with the quarry IN FRONT (positive Z)
--  - Chest is directly BEHIND the turtle
--  - Turtles are lined up along X; job.xOffset moves sideways in +X

local inventory = require("inventory")
local lane_miner = {}

-- Lava-aware fuel logic: try lava buckets first so the empty bucket stays.
local function ensureFuel()
    local level = turtle.getFuelLevel()
    if level == "unlimited" or level > 500 then return true end

    -- 1) Prefer lava buckets (keep empty bucket)
    for slot = 1, 16 do
        turtle.select(slot)
        local detail = turtle.getItemDetail()
        if detail and detail.name == "minecraft:lava_bucket" then
            turtle.refuel(1) -- consumes lava, leaves empty bucket
            level = turtle.getFuelLevel()
            if level > 500 then return true end
        end
    end

    -- 2) Fallback: any other fuel
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.refuel(0) then
            turtle.refuel(64)
            level = turtle.getFuelLevel()
            if level > 500 then return true end
        end
    end

    return turtle.getFuelLevel() > 0
end

local function digAround()
    if turtle.detect() then turtle.dig() end
    if turtle.detectUp() then turtle.digUp() end
    if turtle.detectDown() then turtle.digDown() end
end

local function safeForward()
    ensureFuel()
    while true do
        digAround()
        if turtle.forward() then break end
        sleep(0.1)
    end
end

local function safeDown()
    ensureFuel()
    while true do
        digAround()
        if turtle.down() then break end
        sleep(0.1)
    end
end

-- Mine just this cell (clear below), and check inventory.
local function mineCell()
    -- clear below
    while turtle.detectDown() do
        turtle.digDown()
        sleep(0.05)
    end

    if inventory.isFull() then
        inventory.dumpToChest()
    end
end

-- Mine one horizontal layer of EXACT size: width (X) × depth (Z)
-- Pattern:
--  - Start each row at the NEAR side (small Z), moving forward along Z
--  - For each row:
--      - Walk width cells along X (back and forth for serpentine)
--      - Return to X = 0 (near side) before moving to next Z row
local function mineLayer(width, depth, layerIndex, totalLayers, statusCallback)
    -- At the start of this function, we assume:
    --  - We are at X = 0, Z = 0 of THIS layer, facing +Z
    for row = 1, depth do
        -- 1) Walk across the row in +X, mining cells
        -- Face +X
        turtle.turnRight()  -- +Z -> +X

        for col = 1, width do
            mineCell()
            if col < width then
                safeForward() -- along +X
            end
        end

        -- 2) Walk back to X = 0 so we stay bounded
        turtle.turnLeft()    -- +X -> +Z
        turtle.turnLeft()    -- +Z -> -X
        for col = 1, width - 1 do
            safeForward()    -- along -X, returning to X=0
        end
        turtle.turnRight()   -- -X -> -Z
        turtle.turnRight()   -- -Z -> +X
        turtle.turnLeft()    -- +X -> +Z (back to facing +Z)

        -- 3) Progress callback
        if statusCallback and totalLayers and layerIndex then
            local totalRows = totalLayers * depth
            local doneRows  = (layerIndex - 1) * depth + row
            local pct       = math.floor((doneRows / totalRows) * 100)
            statusCallback(pct)
        end

        -- 4) Move one block forward along Z to next row, unless this was the last row
        if row < depth then
            safeForward() -- move +Z one block
        end
    end

    -- When we exit:
    --  - We are at X = 0, Z = depth - 1, facing +Z
    -- That’s OK; we'll handle going back (or just layering down) in the caller.
end

-- MAIN entry: called as miner.mine(job, callback) from worker.lua
-- job: { jobId, xOffset, width, depth, height }
function lane_miner.mine(job, statusCallback)
    local width  = job.width
    local depth  = job.depth
    local height = job.height or 10

    -- 1) Move sideways to lane start along +X (using xOffset),
    --    then realign to face +Z into the quarry.
    if job.xOffset and job.xOffset > 0 then
        turtle.turnRight()  -- +Z -> +X
        for _ = 1, job.xOffset do
            safeForward()
        end
        turtle.turnLeft()   -- +X -> +Z
    end

    local totalLayers = height

    for layer = 1, totalLayers do
        mineLayer(width, depth, layer, totalLayers, statusCallback)

        -- Move down exactly one block to start the next layer
        if layer < totalLayers then
            safeDown()
            -- After safeDown, we are still roughly at X=0, Z=depth-1, facing +Z.
            -- We now need to go back along -Z to Z=0 so the layer shape stays fixed.
            -- Currently facing +Z:
            turtle.turnLeft()  -- +Z -> +X
            turtle.turnLeft()  -- +X -> -Z
            for _ = 1, depth - 1 do
                safeForward()  -- move back towards Z = 0
            end
            turtle.turnRight() -- -Z -> -X
            turtle.turnRight() -- -X -> +Z (back to facing +Z at X=0,Z=0 for next layer)
        end
    end

    if statusCallback then
        statusCallback(100)
    end
end

return lane_miner

