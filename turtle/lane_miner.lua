local inventory = require("inventory")
local lane_miner = {}

local function fuel()
    if turtle.getFuelLevel() == "unlimited" then return end
    if turtle.getFuelLevel() < 200 then
        for i=1,16 do
            turtle.select(i)
            if turtle.refuel(0) then turtle.refuel(64) end
        end
    end
end

local function digAll()
    if turtle.detect() then turtle.dig() end
    if turtle.detectUp() then turtle.digUp() end
    if turtle.detectDown() then turtle.digDown() end
end

local function forward()
    fuel()
    digAll()
    while not turtle.forward() do digAll() sleep(0.1) end
end

local function down()
    fuel()
    digAll()
    while not turtle.down() do digAll() sleep(0.1) end
end

function lane_miner.mineLane(job, cb)
    -- MOVE +X TO LANE
    turtle.turnRight()
    for i=1,job.xOffset do forward() end
    turtle.turnLeft()

    for y=1,job.height do
        local dir = true
        for z=1,job.depth do
            for x=1,job.width do
                digAll()
                if x < job.width then forward() end
            end
            if z < job.depth then
                if dir then
                    turtle.turnRight() forward() turtle.turnRight()
                else
                    turtle.turnLeft() forward() turtle.turnLeft()
                end
                dir = not dir
            end
            if cb then cb(math.floor((y/job.height)*100)) end
        end
        if y < job.height then down() end
    end
end

return lane_miner
