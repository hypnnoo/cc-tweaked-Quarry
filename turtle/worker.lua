-- turtle/worker.lua
-- Miner worker that requests jobs, mines lanes, and reports progress/fuel/GPS.

local protocol   = require("protocol")
local lane_miner = require("lane_miner")

local modem = peripheral.find("modem") or error("No modem attached")
modem.open(protocol.CHANNEL)

local id = os.getComputerLabel() or ("turtle_" .. os.getComputerID())

local currentJob = nil
local status     = "idle"
local progress   = 0

local lastX, lastY, lastZ = nil, nil, nil

local function updateGPS()
    local x, y, z = gps.locate(2)
    if x then
        lastX, lastY, lastZ = x, y, z
    end
end

local function send(msg)
    modem.transmit(protocol.CHANNEL, protocol.CHANNEL, protocol.encode(msg))
end

local function heartbeatLoop()
    while true do
        updateGPS()
        send(protocol.heartbeat(
            id,
            status,
            currentJob and currentJob.jobId or nil,
            progress,
            turtle.getFuelLevel(),
            lastX,
            lastY,
            lastZ
        ))
        sleep(5)
    end
end

local function miningLoop()
    -- initial hello
    send(protocol.hello(id))

    while true do
        if not currentJob then
            status   = "idle"
            progress = 0
            send(protocol.jobRequest(id))
            sleep(3)
        else
            status   = "mining"
            progress = 0

            lane_miner.mine(currentJob, function(p)
                progress = p
                updateGPS()
                send(protocol.heartbeat(
                    id,
                    status,
                    currentJob.jobId,
                    progress,
                    turtle.getFuelLevel(),
                    lastX,
                    lastY,
                    lastZ
                ))
            end)

            status   = "idle"
            progress = 100
            send(protocol.jobDone(id, currentJob.jobId))
            currentJob = nil
            sleep(2)
        end
    end
end

local function modemLoop()
    while true do
        local _, _, ch, _, msg = os.pullEvent("modem_message")
        if ch == protocol.CHANNEL then
            local d = protocol.decode(msg)
            if d and d.id == id and d.type == "assign_job" then
                currentJob = d.job
            end
        end
    end
end

parallel.waitForAny(heartbeatLoop, miningLoop, modemLoop)
