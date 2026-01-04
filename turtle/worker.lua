local protocol = require("protocol")
local miner    = require("lane_miner")
local inv      = require("inventory")
local nav      = require("navigation")

local modem = peripheral.find("modem") or error("No modem attached")
modem.open(protocol.CHANNEL)

local id = os.getComputerLabel() or ("turtle_" .. os.getComputerID())
local currentJob = nil
local status = "starting"

local startX, startY, startZ = gps.locate(5)

local function log(msg)
    print("[" .. os.clock() .. "] " .. msg)
end

local function send(msg)
    modem.transmit(protocol.CHANNEL, protocol.CHANNEL, protocol.encode(msg))
end

-- 🔥 one-shot pre-refuel so fuel isn’t 0 forever on UI
local function preRefuel()
    if turtle.getFuelLevel() == 0 then
        log("Pre-refuel: trying all slots for lava bucket")
        for i = 1, 16 do
            turtle.select(i)
            turtle.refuel(1)
        end
        turtle.select(1)
        log("Fuel after pre-refuel: " .. tostring(turtle.getFuelLevel()))
    else
        log("Fuel already > 0, skipping pre-refuel")
    end
end

send(protocol.hello(id))
preRefuel()

-- periodic heartbeat so dispatcher sees fuel & status
local function heartbeatLoop()
    while true do
        local fuel = turtle.getFuelLevel()
        send(protocol.heartbeat(
            id,
            status,
            currentJob and currentJob.jobId or nil,
            0,
            fuel
        ))
        sleep(5)
    end
end

local function miningLoop()
    while true do
        if not currentJob then
            status = "idle"
            log("No job, requesting one...")
            send(protocol.jobRequest(id))
            sleep(3)
        else
            status = "mining"
            log("Starting job " .. tostring(currentJob.jobId))

            local result = miner.mine(currentJob, function(p)
                send(protocol.heartbeat(id, status, currentJob.jobId, p, turtle.getFuelLevel()))
            end)

            if result == "FULL" then
                log("Inventory full, returning to surface to dump")
                status = "unloading"
                if startY then
                    pcall(function()
                        nav.returnToSurface(startX, startY, startZ)
                    end)
                end
                inv.dumpToChest()
                -- keep currentJob so we can resume mining it
            else
                log("Job " .. tostring(currentJob.jobId) .. " complete")
                send(protocol.jobDone(id, currentJob.jobId))
                currentJob = nil
            end

            sleep(1)
        end
    end
end

local function modemLoop()
    while true do
        local _, side, ch, reply, msg = os.pullEvent("modem_message")
        if ch ~= protocol.CHANNEL then goto continue end

        local data = protocol.decode(msg)
        if not data or data.id ~= id then goto continue end

        if data.type == "assign_job" then
            log("Received job assignment " .. tostring(data.job and data.job.jobId))
            currentJob = data.job
        end

        ::continue::
    end
end

parallel.waitForAny(heartbeatLoop, miningLoop, modemLoop)

