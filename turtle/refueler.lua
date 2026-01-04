-- turtle/refueler.lua
-- Smart refueler:
--  - Listens for miner heartbeats (fuel levels + GPS coords)
--  - Tracks which turtles are low on fuel
--  - For each "low fuel" turtle:
--      * ensure a lava bucket (from lava pool under home)
--      * walk via GPS to that turtle's current coordinates
--      * drop the bucket directly into the turtle's inventory
--      * walk back home via GPS

local protocol = require("protocol")

local modem = peripheral.find("modem") or error("No modem attached to refueler")
modem.open(protocol.CHANNEL)

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local FUEL_THRESHOLD       = 20000  -- when a miner is considered "low"
local MAX_SERVICE_ATTEMPTS = 3

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local turtles   = {}   -- id -> { fuel, x, y, z, attempts, inQueue }
local fuelQueue = {}   -- FIFO queue of turtle IDs

-- Refueler GPS + facing
local homeX, homeY, homeZ = nil, nil, nil
local facing              = nil  -- "north","south","east","west"

----------------------------------------------------------------
-- MOVEMENT HELPERS (GPS-aware)
----------------------------------------------------------------

local function safeDig()
    if turtle.detect() then
        turtle.dig()
        sleep(0.05)
    end
end

local function safeForward()
    while not turtle.forward() do
        safeDig()
        sleep(0.05)
    end
end

local function safeUp()
    while not turtle.up() do
        if turtle.detectUp() then turtle.digUp() end
        sleep(0.05)
    end
end

local function safeDown()
    while not turtle.down() do
        if turtle.detectDown() then turtle.digDown() end
        sleep(0.05)
    end
end

local function turnLeft()
    turtle.turnLeft()
    if facing == "north" then
        facing = "west"
    elseif facing == "west" then
        facing = "south"
    elseif facing == "south" then
        facing = "east"
    elseif facing == "east" then
        facing = "north"
    end
end

local function turnRight()
    turtle.turnRight()
    if facing == "north" then
        facing = "east"
    elseif facing == "east" then
        facing = "south"
    elseif facing == "south" then
        facing = "west"
    elseif facing == "west" then
        facing = "north"
    end
end

local function face(dir)
    if facing == nil then return end
    while facing ~= dir do
        turnRight()
    end
end

local function currentPos()
    local x, y, z = gps.locate(3)
    return x, y, z
end

local function moveTo(targetX, targetY, targetZ)
    local x, y, z = currentPos()
    if not x then
        print("[Refueler] GPS unavailable while moving!")
        return
    end

    -- Move vertically first to avoid weird holes
    while y < targetY do
        safeUp()
        x, y, z = currentPos()
    end
    while y > targetY do
        safeDown()
        x, y, z = currentPos()
    end

    -- Move in X
    while x ~= targetX do
        if x < targetX then
            face("east")
        else
            face("west")
        end
        safeForward()
        x, y, z = currentPos()
    end

    -- Move in Z
    while z ~= targetZ do
        if z < targetZ then
            face("south")
        else
            face("north")
        end
        safeForward()
        x, y, z = currentPos()
    end
end

----------------------------------------------------------------
-- INITIAL GPS + FACING CALIBRATION
----------------------------------------------------------------

local function calibrateHomeAndFacing()
    local x1, y1, z1 = gps.locate(5)
    if not x1 then
        error("[Refueler] GPS locate failed at startup (need working GPS constellation).")
    end
    homeX, homeY, homeZ = x1, y1, z1

    -- Calibrate facing by moving forward one block and seeing how coords change
    safeForward()
    local x2, y2, z2 = gps.locate(5)
    if not x2 then
        error("[Refueler] GPS locate failed during facing calibration.")
    end

    local dx = x2 - x1
    local dz = z2 - z1

    if dx == 1 and dz == 0 then
        facing = "east"
    elseif dx == -1 and dz == 0 then
        facing = "west"
    elseif dz == 1 and dx == 0 then
        facing = "south"
    elseif dz == -1 and dx == 0 then
        facing = "north"
    else
        error("[Refueler] Could not determine facing from GPS delta.")
    end

    -- Move back to original home position
    face( (dx == 1 and "west")
       or (dx == -1 and "east")
       or (dz == 1 and "north")
       or "south" )
    safeForward()
    face("north")  -- arbitrary default; facing var will be updated accordingly by turns
    -- Re-snap home coords
    homeX, homeY, homeZ = gps.locate(5)
    print(string.format("[Refueler] Home at (%.1f, %.1f, %.1f), facing %s", homeX, homeY, homeZ, tostring(facing)))
end

----------------------------------------------------------------
-- BUCKET / LAVA HANDLING
----------------------------------------------------------------

local function findFullLavaBucket()
    for slot = 1, 16 do
        local d = turtle.getItemDetail(slot)
        if d and d.name == "minecraft:lava_bucket" then
            return slot
        end
    end
    return nil
end

local function findEmptyBucket()
    for slot = 1, 16 do
        local d = turtle.getItemDetail(slot)
        if d and d.name == "minecraft:bucket" then
            return slot
        end
    end
    return nil
end

-- Ensure we have a full lava bucket, using lava directly beneath home
local function ensureFullBucket()
    local fullSlot = findFullLavaBucket()
    if fullSlot then
        return fullSlot
    end

    local emptySlot = findEmptyBucket()
    if not emptySlot then
        print("[Refueler] No empty buckets available!")
        return nil
    end

    turtle.select(emptySlot)
    -- Must be standing over a lava source block
    if turtle.placeDown() then
        local d = turtle.getItemDetail(emptySlot)
        if d and d.name == "minecraft:lava_bucket" then
            return emptySlot
        end
    else
        print("[Refueler] Failed to pick up lava from below.")
    end

    return nil
end

----------------------------------------------------------------
-- QUEUE / MESSAGE HANDLING
----------------------------------------------------------------

local function enqueueFuelRequest(id)
    local t = turtles[id] or {}
    turtles[id] = t
    if t.inQueue then return end
    t.inQueue   = true
    t.attempts  = t.attempts or 0
    table.insert(fuelQueue, id)
    print("[Refueler] Queued low-fuel turtle:", id)
end

local function handleHeartbeat(d)
    local id   = d.id
    local fuel = tonumber(d.fuel or 0) or 0
    turtles[id]      = turtles[id] or {}
    turtles[id].fuel = fuel
    turtles[id].x    = d.x
    turtles[id].y    = d.y
    turtles[id].z    = d.z

    if fuel > 0 and fuel < FUEL_THRESHOLD and d.x and d.y and d.z then
        enqueueFuelRequest(id)
    end
end

local function handleAssignJob(d)
    -- Reserved for future multi-turtle routing; not required for GPS pathing.
    local id = d.id
    turtles[id] = turtles[id] or {}
end

local function eventLoop()
    while true do
        local _, _, ch, _, msg = os.pullEvent("modem_message")
        if ch == protocol.CHANNEL then
            local d = protocol.decode(msg)
            if d and d.id then
                if d.type == "heartbeat" then
                    handleHeartbeat(d)
                elseif d.type == "assign_job" then
                    handleAssignJob(d)
                end
            end
        end
    end
end

----------------------------------------------------------------
-- REFUEL SERVICE LOOP
----------------------------------------------------------------

local function serviceLoop()
    while true do
        if #fuelQueue == 0 then
            sleep(2)
        else
            local id   = table.remove(fuelQueue, 1)
            local data = turtles[id]
            if not data then
                -- nothing known about this turtle
            else
                data.inQueue  = false
                data.attempts = (data.attempts or 0) + 1

                if data.attempts > MAX_SERVICE_ATTEMPTS then
                    print("[Refueler] Giving up on turtle:", id)
                elseif not (data.x and data.y and data.z) then
                    print("[Refueler] No GPS coords for turtle:", id)
                else
                    print(string.format("[Refueler] Servicing turtle %s at (%.1f, %.1f, %.1f)",
                        id, data.x, data.y, data.z))

                    local bucketSlot = ensureFullBucket()
                    if bucketSlot then
                        -- 1) Go from home to turtle position
                        moveTo(data.x, data.y, data.z)

                        -- 2) Drop lava bucket directly into turtle inventory
                        turtle.select(bucketSlot)
                        turtle.drop(1)

                        -- 3) Return home
                        moveTo(homeX, homeY, homeZ)
                    end
                end
            end
        end
    end
end

----------------------------------------------------------------
-- START
----------------------------------------------------------------

print("[Refueler] Starting GPS-based refueler...")
calibrateHomeAndFacing()
print("[Refueler] Listening for low-fuel miners...")
parallel.waitForAny(eventLoop, serviceLoop)
