-- turtle/lane_miner.lua
-- Mines a rectangular lane width x depth x height.
-- Features:
--  - Exact footprint: width (X) by depth (Z) starting from the block IN FRONT of the turtle
--  - 200+ layers down (height)
--  - Skip-mines air (only digs blocks that exist)
--  - Batch unload when inventory is near-full (using inventory.dumpToChest)
--  - Skips already completed layers on resume via progress files
--  - When low on fuel, tries inventory then tries sucking from chest behind
--  - Will NOT mine other turtles; stops instead of crashing through

local inventory = require("inventory")
local lane_miner = {}

local NEAR_FULL_EMPTY_SLOTS = 2  -- dump when <= this many empty slots

----------------------------------------------------------------
-- Turtle detection helpers
----------------------------------------------------------------
local function isTurtleBlock(data)
    return data and data.name and data.name:lower():find("turtle") ~= nil
end

----------------------------------------------------------------
-- Progress persistence per job
----------------------------------------------------------------
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

----------------------------------------------------------------
-- Fuel handling
----------------------------------------------------------------
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

local function ensureFuel()
    local lvl = turtle.getFuelLevel()
    if lvl == "unlimited" or lvl > 500 then return true end

    if tryRefuelFromInventory() then return true end
    return tryRefuelFromChestBehind()
end

----------------------------------------------------------------
-- Digging helpers (turtle-safe)
----------------------------------------------------------------
local function digForward()
    local ok, data = turtle.inspect()
    if ok then
        if isTurtleBlock(data) then
            -- Another turtle ahead: DO NOT dig it.
            return
        end
        turtle.dig()
        sleep(0.05)
    end
end

local function digUp()
    local ok, data = turtle.inspectUp()
    if ok then
        if isTurtleBlock(data) then
            return
        end
        turtle.digUp()
        sleep(0.05)
    end
end

local function digDown()
    while true do
        local ok, data = turtle.inspectDown()
        if not ok then break end
        if isTurtleBlock(data) then
            -- Turtle below us; don't mine it
            break
        end
        if not turtle.detectDown() then
            break
        end
        turtle.digDown()
        sleep(0.05)
    end
end

----------------------------------------------------------------
-- Safe movement (stops if a turtle is in the way)
----------------------------------------------------------------
local function safeForward()
    ensureFuel()

    local tries = 0
    while true do
        local ok, data = turtle.inspect()
        if ok and isTurtleBlock(data) then
            print("Turtle ahead, stopping to avoid collision.")
            return false
        end

        digForward()
        digUp()

        if turtle.forward() then
            return true
        end

        tries = tries + 1
        if tries > 50 then
            print("Blocked, giving up on forward move.")
            return false
        end

        sleep(0.05)
    end
end

local function safeDown()
    ensureFuel()

    local tries = 0
    while true do
        local ok, data = turtle.inspectDown()
        if ok and isTurtleBlock(data) then
            print("Turtle below, stopping to avoid collision.")
            return false
        end

        digDown()

        if turtle.down() then
            return true
        end

        tries = tries + 1
        if tries > 50 then
            print("Blocked, giving up on down move.")
            return false
        end

        sleep(0.05)
    end
end

----------------------------------------------------------------
-- Mining a single cell
----------------------------------------------------------------
local function mineCell()
    digDown()
    if inventory.isFull(NEAR_FULL_EMPTY_SLOTS) then
        inventory.dumpToChest()
    end
end

----------------------------------------------------------------
-- One horizontal layer: EXACT width (X) × depth (Z)
-- Assumes:
--  - We start at the FRONT row of this layer
--  - Facing +Z into the quarry
----------------------------------------------------------------
local function mineLayer(width, depth, layerIndex, totalLayers, statusCallback, jobId)
    local goingPositiveX = true  -- true = +X, false = -X

    for row = 1, depth do
        if goingPositiveX then
            turtle.turnRight()  -- +Z -> +X
            for col = 1, width do
                mineCell()
                if col < width then
                    if not safeForward() then
                        turtle.turnLeft() -- restore facing +Z
                        return
                    end
                end
            end
            turtle.turnLeft()   -- +X -> +Z
        else
            turtle.turnLeft()   -- +Z -> -X
            for col = 1, width do
                mineCell()
                if col < width then
                    if not safeForward() then
                        turtle.turnRight() -- restore facing +Z
                        return
                    end
                end
            end
            turtle.turnRight()  -- -X -> +Z
        end

        -- Progress update
        if statusCallback and totalLayers and layerIndex then
            local totalRows = totalLayers * depth
            local doneRows  = (layerIndex - 1) * depth + row
            local pct       = math.floor((doneRows / totalRows) * 100)
            statusCallback(pct)
        end

        -- Move to next row along +Z (within this layer)
        if row < depth then
            if not safeForward() then
                return
            end
            goingPositiveX = not goingPositiveX
        end
    end
end

----------------------------------------------------------------
-- MAIN entry: lane_miner.mine(job, statusCallback)
-- NOTE: We now step FORWARD ONCE into the quarry before mining,
--       so depth=16 really means "16 blocks in front of the turtle".
----------------------------------------------------------------
function lane_miner.mine(job, statusCallback)
    local width  = job.width
    local depth  = job.depth
    local height = job.height or 10
    local jobId  = job.jobId

    ----------------------------------------------------------------
    -- 1) Move sideways to lane start (if using xOffset), then face +Z
    ----------------------------------------------------------------
    if job.xOffset and job.xOffset > 0 then
        turtle.turnRight()  -- +Z -> +X
        for _ = 1, job.xOffset do
            if not safeForward() then
                turtle.turnLeft()
                return
            end
        end
        turtle.turnLeft()   -- +X -> +Z
    end

    ----------------------------------------------------------------
    -- 2) Step one block forward into the quarry
    --    This makes depth=16 mean "16 blocks forward from the block
    --    in front of the turtle", not counting the line it's sitting on.
    ----------------------------------------------------------------
    if not safeForward() then
        return
    end

    ----------------------------------------------------------------
    -- 3) Load last completed layer and skip down to it (vertical only)
    ----------------------------------------------------------------
    local startLayer = loadProgress(jobId)
    if startLayer > 1 then
        for _ = 1, startLayer - 1 do
            if not safeDown() then
                return
            end
        end
    end

    ----------------------------------------------------------------
    -- 4) Mine layers
    ----------------------------------------------------------------
    local totalLayers = height

    for layer = startLayer, totalLayers do
        mineLayer(width, depth, layer, totalLayers, statusCallback, jobId)
        saveProgress(jobId, layer)

        if layer < totalLayers then
            if not safeDown() then
                break
            end
        end
    end

    -- job completed or aborted: reset saved layer
    saveProgress(jobId, 1)

    if statusCallback then
        statusCallback(100)
    end
end

return lane_miner
