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

-- PATH DISTANCES FROM REFUELER "HOME" TO THE QUARRY TURTLE
-- Assumptions:
--  - Refueler starts at home, FACING roughly toward the quarry turtle.
--  - From refueler home:
--      * quarry turtle is 5 blocks FORWARD (in front)
--      * then 10 blocks LEFT
--  - When we arrive, we are adjacent to the turtle and can drop the bucket
--    directly into its inventory with turtle.drop(1).
local FORWARD_STEPS_TO_TURTLE = 5
local LEFT_STEPS_TO_TURTLE    = 10

-- ASSUMPTIONS:
--  - Refueler stands at "home" over a lava source block.
--  - There is a lava source directly BELOW home.
--  - Currently we treat all miners the same and go to the same turtle position.
--    (If you add more miners later, we can expand this to per-id paths.)
----------------------------------------------------------------

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local turtles = {}   -- id -> { fuel, needsFuel, attempts }
local fuelQueue = {} -- { id1, id2, ... }

----------------------------------------------------------------
-- MOVEMENT HELPERS
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
-- PATHING
----------------------------------------------------------------

-- Go from "home" to a position DIRECTLY IN FRONT/ADJACENT to the quarry turtle,
-- using the given forward/left offsets.
local function goToTurtle(id, data)
    -- Start: at home, facing toward turtle.

    -- 1) Go forward 5 blocks
    for _ = 1, FORWARD_STEPS_TO_TURTLE do
        safeForward()
    end

    -- 2) Turn left and go 10 blocks
    turtle.turnLeft()
    for _ = 1, LEFT_STEPS_TO_TURTLE do
        safeForward()
    end

    -- 3) Turn right to roughly face the turtle
    turtle.turnRight()
    -- Now we should be standing by the turtle and facing it (or its side).
    -- turtle.drop(1) from here should put the bucket into its inventory.
end

-- Go back from that turtle position to "home", reversing the path.
local function goHome(data)
    -- We assume we are facing the turtle.
    -- Reverse the path:
    -- 1) Turn around to face away
    turtle.turnLeft()
    turtle.turnLeft()

    -- 2) Go back LEFT_STEPS_TO_TURTLE (which is now "right" from original)
    for _ = 1, LEFT_STEPS_TO_TURTLE do
        safeForward()
    end

    -- 3) Turn right to face back toward home
    turtle.turnRight()

    -- 4) Go back FORWARD_STEPS_TO_TURTLE
    for _ = 1, FORWARD_STEPS_TO_TURTLE do
        safeForward()
    end

    -- 5) Turn around so we face the original "toward turtle" direction again
    turtle.turnLeft()
    turtle.turnLeft()
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
    -- We don't actually need job info for single-turtle direct delivery,
    -- but we keep the handler in case you expand later.
    local id  = d.id
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
                        -- 2) Walk to position in front/adjacent to this turtle
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
