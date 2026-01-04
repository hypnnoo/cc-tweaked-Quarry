local inv=require("inventory")
local m={}

local function refuel()
    if turtle.getFuelLevel()=="unlimited" then return end
    if turtle.getFuelLevel()>500 then return end
    for s=1,16 do
        turtle.select(s)
        local d=turtle.getItemDetail()
        if d and d.name=="minecraft:lava_bucket" then
            turtle.refuel(1)
            return
        end
    end
end

local function dig()
    if turtle.detect() then turtle.dig() end
    if turtle.detectUp() then turtle.digUp() end
    if turtle.detectDown() then turtle.digDown() end
end

local function fwd()
    refuel() dig()
    while not turtle.forward() do dig() sleep(0.1) end
end

local function down()
    refuel() dig()
    while not turtle.down() do dig() sleep(0.1) end
end

function m.mine(job,cb)
    turtle.turnRight()
    for i=1,job.xOffset do fwd() end
    turtle.turnLeft()

    for y=1,job.height do
        local dir=true
        for z=1,job.depth do
            for x=1,job.width do
                if inv.isFull() then return "FULL" end
                dig()
                if x<job.width then fwd() end
            end
            if z<job.depth then
                if dir then turtle.turnRight() fwd() turtle.turnRight()
                else turtle.turnLeft() fwd() turtle.turnLeft() end
                dir=not dir
            end
        end
        if cb then cb(math.floor((y/job.height)*100)) end
        if y<job.height then down() end
    end
end

return m
