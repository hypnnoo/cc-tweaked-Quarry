-- turtle/lane_miner.lua
-- Simplified lane miner with:
--  - skip-mining air blocks
--  - batch unload only when inventory is near-full

local inventory = require("inventory")

local lane_miner = {}

-- how many empty slots we still allow before dumping
local NEAR_FULL_EMPTY_SLOTS = 2

-- Fuel: prefer lava buckets, fall back to any fuel
local function ensureFuel()
    local lvl = turtle.getFuelLevel()
    if lvl == "unlimited" or lvl > 500 then return true end

    -- 1) Lava buckets first
    for slot = 1, 16 do
        turtle.select(slot)
        local detail = turtle.getItemDetail()
        if detail and detail.name == "minecraft:lava_bucket" then
            turtle.refuel(1)  -- consumes lava, leaves empty bucket
            lvl = turtle.getFuelLevel()
            if lvl > 500 then return true end
        end
    end

    -- 2) Any other fuel
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.refuel(0) then
            turtle.refuel(64)
            lvl = turtle.getFuelLevel()
            if lvl > 500 then return true end
        end
    end

    return turtle.getFuelLevel() > 0
end

local function digForward()
    if turtle.detect() then
        turtle.dig()
        sleep(0.05)
    end
end

local function digUp()
    if turtle.detectUp() then
        turtle.digUp()
        sleep(0.05)
    end
end

local function digDown()
    -- skip-mining: only dig if there is actually a block
    while turtle.detectDown() do
        turtle.digDown()
        sleep(0.05)
    end
end

local function safeForward()
    ensureFuel()

    -- skip-mining air: only dig if needed
    digForward()
    digUp()

    while not turtle.forward() do
        digForward()
        sleep(0.05)
    end
end

local function safeDown()
    ensureFuel()
    digDown()
    while not turtle.down() do
        digDown()
        sleep(0.05)
    end
end

-- Mine just this cell (mainly: clear below and batch-unload if near-full)
local function mineCell()
    digDown()

    -- Batch unload only when inventory is near-full
    if inventory.isFull(NEAR_FULL_EMPTY_SLOTS) then
        inventory.dumpToChest()
    end
end

-- Mine one horizontal layer of EXACT size: width (X) × depth (Z)
-- Pattern:
--  - Start each layer at lane's near corner, facing +Z into quarry
--  - Walk rows along Z, snake along X
local function mineLayer(width, depth, layerIndex, totalLayers, statusCallback)
    -- We assume:
    --  - Starting at near edge of this lane
    --  - Facing +Z

    local goingPositiveX = true

    for row = 1, depth do
        -- 1) Walk across the row in X
        if goingPositiveX then
            -- face +X
            turtle.turnRight()  -- +Z -> +X
            for col = 1, width do
                mineCell()
                if col < width then
                    safeForward()
                end
            end
            turtle.turnLeft()   -- +X -> +Z
        else
            -- face -X
            turtle.turnLeft()   -- +Z -> -X
            for col = 1, width do
                mineCell()
                if col < width then
                    safeForward()
                end
            end
            turtle.turnRight()  -- -X -> +Z
        end

        -- 2) Progress callback per row
        if statusCallback and totalLayers and layerIndex then
            local totalRows = totalLayers * depth
            local doneRows  = (layerIndex - 1) * depth + row
            local pct       = math.floor((doneRows / totalRows) * 100)
            statusCallback(pct)
        end

        -- 3) Move one block forward along Z to next row, unless last row
        if row < depth then
            safeForward()
            goingPositiveX = not goingPositiveX
        end
    end
end

-- MAIN entry: called as miner.mine(job, callback) from worker.lua
-- job: { jobId, xOffset, width, depth, height }
function lane_miner.mine(job, statusCallback)
    local width  = job.width
    local depth  = job.depth
    local height = job.height or 10

    -- 1) Move sideways along +X to lane start (xOffset), then face +Z
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

        -- 2) Go down one block to start next layer, if any
        if layer < totalLayers then
            safeDown()
        end
    end

    if statusCallback then
        statusCallback(100)
    end
end

return lane_miner

