local inventory = require("inventory")

local lane_miner = {}

-- Refuel using lava buckets if fuel is low
local function ensureFuel()
    local level = turtle.getFuelLevel()
    if level == "unlimited" or level > 500 then return end

    for slot = 1, 16 do
        turtle.select(slot)
        local detail = turtle.getItemDetail()
        if detail and detail.name == "minecraft:lava_bucket" then
            turtle.refuel(1) -- consumes lava, leaves empty bucket
            return
        end
    end
end

local function digAround()
    if turtle.detect() then turtle.dig() end
    if turtle.detectUp() then turtle.digUp() end
    if turtle.detectDown() then turtle.digDown() end
end

local function forward()
    ensureFuel()
    digAround()
    while not turtle.forward() do
        digAround()
        sleep(0.1)
    end
end

local function down()
    ensureFuel()
    digAround()
    while not turtle.down() do
        digAround()
        sleep(0.1)
    end
end

local function mineCurrentCell()
    digAround()
    if inventory.isFull() then
        return false
    end
    return true
end

function lane_miner.mineLane(job, statusCallback)
    local width  = job.width   -- X size of this lane
    local depth  = job.depth   -- Z size
    local height = job.height or 10

    -- 1) Move sideways along X to the start of this lane
    -- Start assumption: turtle is facing +Z
    turtle.turnRight() -- now facing +X
    for i = 1, job.xOffset do
        forward()
    end
    -- stay facing +X here for serpentine
    local dir = 1 -- +X to start

    local totalCells = width * depth * height
    local minedCells = 0

    for layer = 1, height do
        for row = 1, depth do
            -- mine starting cell of this row
            if not mineCurrentCell() then
                if statusCallback then
                    statusCallback(math.floor((minedCells / totalCells) * 100))
                end
                return "FULL"
            end
            minedCells = minedCells + 1

            -- traverse rest of row along X (width-1 moves)
            for step = 1, width - 1 do
                forward() -- along current X direction
                if not mineCurrentCell() then
                    if statusCallback then
                        statusCallback(math.floor((minedCells / totalCells) * 100))
                    end
                    return "FULL"
                end
                minedCells = minedCells + 1
            end

            -- move to next row along Z (if any), flip X direction
            if row < depth then
                if dir == 1 then
                    -- currently facing +X, go +Z, end facing -X
                    turtle.turnLeft()
                    forward()  -- +Z
                    turtle.turnLeft()
                    dir = -1
                else
                    -- currently facing -X, go +Z, end facing +X
                    turtle.turnRight()
                    forward()  -- +Z
                    turtle.turnRight()
                    dir = 1
                end
            end

            if statusCallback then
                statusCallback(math.floor((minedCells / totalCells) * 100))
            end
        end

        -- go down one layer
        if layer < height then
            down()
        end
    end

    if statusCallback then
        statusCallback(100)
    end
end

return lane_miner
