local inventory = require("inventory")

local lane_miner = {}

local function ensureFuel()
    local level = turtle.getFuelLevel()
    if level == "unlimited" or level > 500 then return end

    for slot = 1, 16 do
        turtle.select(slot)
        local detail = turtle.getItemDetail()
        if detail and detail.name == "minecraft:lava_bucket" then
            turtle.refuel(1) -- consume lava, keep empty bucket
            return
        end
    end
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

local function mineCell()
    digAround()
    if inventory.isFull() then
        return false
    end
    return true
end

-- MUST be called as miner.mine(job, callback) from worker.lua
function lane_miner.mine(job, statusCallback)
    local width  = job.width   -- X size
    local depth  = job.depth   -- Z size
    local height = job.height or 10

    -- Start assumption:
    --  - Turtle is on the top-left corner of the area
    --  - Facing into the quarry (+Z)
    --  - xOffset is how far to move RIGHT (along X) before starting
    --
    -- Move sideways along X to lane start
    turtle.turnRight()     -- +Z -> +X
    for i = 1, job.xOffset do
        safeForward()
    end
    turtle.turnLeft()      -- back to +Z

    local totalCells = width * depth * height
    local minedCells = 0

    -- Serpentine pattern, column-by-column:
    -- X = 1..width (columns), Z = 1..depth (rows within each column)
    -- We always mine exactly width * depth cells per layer.
    local forwardPositiveZ = true  -- true = +Z, false = -Z

    for layer = 1, height do
        for col = 1, width do
            -- each column: depth cells along Z
            for row = 1, depth do
                if not mineCell() then
                    if statusCallback and totalCells > 0 then
                        statusCallback(math.floor((minedCells / totalCells) * 100))
                    end
                    return "FULL"
                end

                minedCells = minedCells + 1

                if row < depth then
                    safeForward()   -- move along current Z direction
                end
            end

            -- Move to next column (X) if any
            if col < width then
                if forwardPositiveZ then
                    -- we ended at far side (+Z), want to step +X and go back -Z
                    turtle.turnRight()   -- +Z -> +X
                    safeForward()        -- +X, move to next column
                    turtle.turnRight()   -- +X -> -Z
                    forwardPositiveZ = false
                else
                    -- we ended at near side (-Z), want to step +X and go back +Z
                    turtle.turnLeft()    -- -Z -> +X
                    safeForward()        -- +X
                    turtle.turnLeft()    -- +X -> +Z
                    forwardPositiveZ = true
                end
            end
        end

        -- Move down one layer
        if layer < height then
            safeDown()
        end
    end

    if statusCallback then
        statusCallback(100)
    end
end

return lane_miner
