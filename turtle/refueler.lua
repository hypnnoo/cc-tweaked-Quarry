-- turtle/refueler.lua
-- Smart refueler:
--  - Listens for miner heartbeats (fuel levels)
--  - Tracks which turtles are low on fuel
--  - For each "low fuel" turtle:
--      * fill a lava bucket from pool beneath refueler
--      * walk to that turtle and drop the bucket directly into its inventory
--      * return home

local protocol = require("protocol")

local modem = peripheral.find("modem") or error("No modem attached to refueler")
modem.open(protocol.CHANNEL)

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
-- Fuel threshold at which a turtle is considered "low"
local FUEL_THRESHOLD = 20000

-- How many times we try to service each low turtle before giving up
local MAX_SERVICE_ATTEMPTS = 3

-- ASSUMPTIONS:
--  - Refueler starts at a known "home" position, standing on a solid block
--  - There is a LAVA SOURCE BLOCK directly below "home"
--  - Each miner turtle is reachable by some path from "home"
--  - When we are standing one block in front of a miner turtle and facing it,
--    calling turtle.drop(1) will put a lava bucket directly into its inventory.
--
--  - You MUST edit goToTurtle(id, data) and goHome(data) to match your world layout.
----------------------------------------------------------------

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local turtles = {}   -- id -> { fuel, needsFuel, attempts, laneOffset }
local fuelQueue = {} -- { id1, id2, ... }

----------------------------------------------------------------
-- MOVEMENT HELPERS (safe-ish)
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

----------------------------------------------------------------
-- PATHING: EDIT THESE FOR YOUR BASE LAYOUT
----------------------------------------------------------------

-- Go from "home" to a position DIRECTLY IN FRONT OF turtle id,
-- facing the turtle, so that turtle.drop(1) will insert into its inventory.
--
-- data.laneOffset can be used if your miner lanes are spaced along +X.
local function goToTurtle(id, data)
    -- >>> EDIT THIS FUNCTION FOR YOUR WORLD <<<
    --
    -- Example idea if your setup is:
    --  - All miner turtles are in a straight line along +X
    --  - Refueler starts behind lane 1, facing +X
    --  - laneOffset == how many blocks along +X from the first turtle
    --
    -- Then something like this could work:
    --
    -- local offset = data.laneOffset or 0
    -- for _ = 1, offset do
    --     safeForward()   -- walk along +X
    -- end
    -- -- Now, perhaps turn and move forward/backward to get in front of the turtle.
    --
    -- Right now, this is a stub so it doesn't move until you fill it in.
end

-- Go from the last turtle we visited BACK to the "home" position.
--
-- You can use data.laneOffset again to reverse the path you used in goToTurtle.
local function goHome(data)
    -- >>> EDIT THIS FUNCTION TO MATCH goToTurtle <<<
    --
    -- In the simple example above, you'd:
    --  - turn around
    --  - walk `laneOffset` blocks back
    --  - turn back to your original facing
end

----------------------------------------------------------------
-- BUCKET / LAVA HANDLING
----------------------------------------------------------------

-- Find a full lava bucket in inventory; return its slot or nil
local function findFullLavaBucket()
    for slot = 1, 16 do
        local d = turtle.getItemDetail(slot)
        if d and d.name == "minecraft:lava_bucket" then
            return slot
        end
    end
    return nil
end

-- Find an empty bucket
local function findEmptyBucket()
    for slot = 1, 16 do
        local d = turtle.getItemDetail(slot)
        if d and d.name == "minecraft:bucket" then
            return slot
        end
    end
    return nil
end

-- Ensure we have a full lava bucket; if not, try to fill one from lava beneath
local function ensureFullBucket()
    local fullSlot = findFullLavaBucket()
    if fullSlot then
        return fullSlot
    end

    -- No full bucket: try to fill an empty bucket from lava below
    local emptySlot = findEmptyBucket()
    if not emptySlot then
        print("[Refueler] No empty buckets available!")
        return nil
    end

    turtle.select(emptySlot)
    -- This assumes there is a lava source directly under the refueler at home
    if turtle.placeDown() then
        -- Now this slot should contain a lava bucket
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
    t.inQueue = true
    t.attempts = t.attempts or 0
    table.insert(fuelQueue, id)
    print("[Refueler] Queued low-fuel turtle:", id)
end

local function handleHeartbeat(d)
    local id   = d.id
    local fuel = tonumber(d.fuel or 0) or 0
    turtles[id] = turtles[id] or {}
    turtles[id].fuel = fuel

    if fuel > 0 and fuel < FUEL_THRESHOLD then
        enqueueFuelRequest(id)
    end
end

local function handleAssignJob(d)
    local id  = d.id
    local job = d.job or {}
    turtles[id] = turtles[id] or {}
    -- laneOffset lets us know where along X that turtle's lane starts
    turtles[id].laneOffset = job.xOffset or 0
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
            local id = table.remove(fuelQueue, 1)
            local data = turtles[id]
            if not data then
                -- nothing known about this turtle
            else
                data.inQueue = false
                data.attempts = (data.attempts or 0) + 1

                if data.attempts > MAX_SERVICE_ATTEMPTS then
                    print("[Refueler] Giving up on turtle:", id)
                else
                    print("[Refueler] Servicing turtle:", id)

                    -- 1) Ensure we have a full lava bucket
                    local bucketSlot = ensureFullBucket()
                    if bucketSlot then
                        -- 2) Walk to position in front of this turtle
                        goToTurtle(id, data)

                        -- 3) Drop ONE lava bucket directly into the turtle's inventory
                        turtle.select(bucketSlot)
                        turtle.drop(1)

                        -- 4) Go back home
                        goHome(data)
                    end
                end
            end
        end
    end
end

----------------------------------------------------------------
-- START
----------------------------------------------------------------
print("[Refueler] Smart direct-delivery refueler started. Listening for low-fuel miners...")
parallel.waitForAny(eventLoop, serviceLoop)
