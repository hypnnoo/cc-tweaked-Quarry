-- turtle/refueler.lua
-- Smart refueler:
--  - Listens for miner heartbeats (fuel levels)
--  - Tracks which turtles are low on fuel
--  - For each "low fuel" turtle:
--      * fill a lava bucket from pool beneath refueler
--      * walk to that turtle and drop the bucket directly into its inventory
--      * return home
--
-- Assumes:
--  - Refueler starts at "home" standing over a lava source block.
--  - From home, quarry miner turtle is 5 blocks FORWARD and 10 blocks LEFT,
--    relative to the refueler's starting facing direction.

local protocol = require("protocol")

local modem = peripheral.find("modem") or error("No modem attached to refueler")
modem.open(protocol.CHANNEL)

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local FUEL_THRESHOLD       = 20000  -- when a miner is considered "low"
local MAX_SERVICE_ATTEMPTS = 3

local FORWARD_STEPS_TO_TURTLE = 5
local LEFT_STEPS_TO_TURTLE    = 10

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local turtles   = {}   -- id -> { fuel, attempts, inQueue }
local fuelQueue = {}   -- FIFO of turtle IDs needing fuel

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

-- From home -> miner turtle (5 forward, 10 left, then face turtle)
local function goToTurtle(id, data)
    -- 1) Go forward 5
    for _ = 1, FORWARD_STEPS_TO_TURTLE do
        safeForward()
    end

    -- 2) Turn left and go 10
    turtle.turnLeft()
    for _ = 1, LEFT_STEPS_TO_TURTLE do
        safeForward()
    end

    -- 3) Turn right to face turtle
    turtle.turnRight()
end

-- From miner turtle back to home (reverse the above path)
local function goHome(data)
    -- Assume we're facing the turtle.
    -- Turn around:
    turtle.turnLeft()
    turtle.turnLeft()

    -- Walk back LEFT_STEPS_TO_TURTLE (now effectively "right" from original)
    for _ = 1, LEFT_STEPS_TO_TURTLE do
        safeForward()
    end

    -- Turn right to face back toward home
    turtle.turnRight()

    -- Walk back FORWARD_STEPS_TO_TURTLE
    for _ = 1, FORWARD_STEPS_TO_TURTLE do
        safeForward()
    end

    -- Turn around to original "toward turtle" direction
    turtle.turnLeft()
    turtle.turnLeft()
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

    if fuel > 0 and fuel < FUEL_THRESHOLD then
        enqueueFuelRequest(id)
    end
end

local function handleAssignJob(d)
    -- Reserved for future multi-turtle routing; not used in single-turtle direct mode
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
                else
                    print("[Refueler] Servicing turtle:", id)

                    local bucketSlot = ensureFullBucket()
                    if bucketSlot then
                        goToTurtle(id, data)

                        -- Drop one lava bucket directly into miner inventory
                        turtle.select(bucketSlot)
                        turtle.drop(1)

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
