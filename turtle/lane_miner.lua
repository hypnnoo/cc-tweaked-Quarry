-- turtle/lane_miner.lua
-- Mines a rectangular lane width x depth x height.
-- Features:
--  - Skip-mines air (only digs blocks that exist)
--  - Batch unload when inventory is near-full
--  - Skips already completed layers on resume via progress files
--  - When low on fuel, tries inventory then tries sucking from chest behind

local inventory = require("inventory")
local lane_miner = {}

local NEAR_FULL_EMPTY_SLOTS = 2  -- dump when <= this many empty slots

-- progress persistence per job
local function progressFile(jobId)
    return "lane_progress_" .. tostring(jobId or "default") .. ".dat"
end

local function saveProgress(jobId, layer)
    local path = progressFile(jobId)
    local h = fs.open(path, "w")
    if not h then return end
    h.writeLine(tostring(layer))
    h.close()
end

local function loadProgress(jobId)
    local path = progressFile(jobId)
    if not fs.exists(path) then return 1 end
    local h = fs.open(path, "r")
    if not h then return 1 end
    local line = h.readLine()
    h.close()
    local n = tonumber(line)
    if not n or n < 1 then n = 1 end
    return n
end

-- Try fuel from inventory only (lava buckets first, then anything)
local function tryRefuelFromInventory()
    local lvl = turtle.getFuelLevel()
    if lvl == "unlimited" or lvl > 500 then return true end

    -- lava buckets first
    for slot = 1, 16 do
        turtle.select(slot)
        local d = turtle.getItemDetail()
        if d and d.name == "minecraft:lava_bucket" then
            turtle.refuel(1)
            lvl = turtle.getFuelLevel()
            if lvl > 500 then
                turtle.select(1)
                return true
            end
        end
    end

    -- other fuel
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.refuel(0) then
            turtle.refuel(64)
            lvl = turtle.getFuelLevel()
            if lvl > 500 then
                turtle.select(1)
                return true
            end
        end
    end

    turtle.select(1)
    return turtle.getFuelLevel() > 0
end

-- Try to suck fuel from chest behind the turtle (lava bucket)
local function tryRefuelFromChestBehind()
    turtle.turnLeft()
    turtle.turnLeft()

    for _ = 1, 4 do
        turtle.suck(1)
        sleep(0.1)
    end

    turtle.turnLeft()
    turtle.turnLeft()

    return tryRefuelFromInventory()
end

-- Ensure we have enough fuel, using inventory then chest behind
local function ensureFuel()
    local lvl = turtle.getFuelLevel()
    if lvl == "unlimited" or lvl > 500 then return true end

    if tryRefuelFromInventory() then return true end
    return tryRefuelFromChestBehind()
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
    while turtle.detectDown() do
        turtle.digDown()
        sleep(0.05)
    end
end

local function safeForward()
    ensureFuel()
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

-- Mine just this cell and batch-unload if near-full
local function mineCell()
    digDown()
    if inventory.isFull(NEAR_FULL_EMPTY_SLOTS) then
        inventory.dumpToChest()
    end
end

-- One horizontal layer: EXACT width (X) × depth (Z)
local function mineLayer(width, depth, layerIndex, totalLayers, statusCallback, jobId)
    local goingPositiveX = true  -- true = +X, false = -X

    for row = 1, depth do
        if goingPositiveX then
            turtle.turnRight()  -- +Z -> +X
            for col = 1, width do
                mineCell()
                if col < width then
                    safeForward()
                end
            end
            turtle.turnLeft()   -- +X -> +Z
        else
            turtle.turnLeft()   -- +Z -> -X
            for col = 1, width do
                mineCell()
                if col < width then
                    safeForward()
                end
            end
            turtle.turnRight()  -- -X -> +Z
        end

        if statusCallback and totalLayers and layerIndex then
            local totalRows = totalLayers * depth
            local doneRows  = (layerIndex - 1) * depth + row
            local pct       = math.floor((doneRows / totalRows) * 100)
            statusCallback(pct)
        end

        if row < depth then
            safeForward()        -- next row along +Z
            goingPositiveX = not goingPositiveX
        end
    end
end

-- MAIN entry: miner.mine(job, callback)
function lane_miner.mine(job, statusCallback)
    local width  = job.width
    local depth  = job.depth
    local height = job.height or 10
    local jobId  = job.jobId

    -- move sideways along +X to lane start, then face +Z
    if job.xOffset and job.xOffset > 0 then
        turtle.turnRight()  -- +Z -> +X
        for _ = 1, job.xOffset do
            safeForward()
        end
        turtle.turnLeft()   -- +X -> +Z
    end

    -- Load last completed layer and skip down to it (vertical only)
    local startLayer = loadProgress(jobId)
    if startLayer > 1 then
        for _ = 1, startLayer - 1 do
            safeDown()
        end
    end

    local totalLayers = height

    for layer = startLayer, totalLayers do
        mineLayer(width, depth, layer, totalLayers, statusCallback, jobId)
        saveProgress(jobId, layer)

        if layer < totalLayers then
            safeDown()
        end
    end

    -- job completed: reset saved layer
    saveProgress(jobId, 1)

    if statusCallback then
        statusCallback(100)
    end
end

return lane_miner
