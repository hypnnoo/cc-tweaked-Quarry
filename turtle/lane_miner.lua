-- turtle/worker.lua

local protocol = require("protocol")
local lane_miner = require("lane_miner")

local modem = peripheral.find("modem")
if not modem then
    error("No modem attached to turtle")
end

local CHANNEL = protocol.CHANNEL
modem.open(CHANNEL)

-- Use computer label as ID, or fallback
local id = os.getComputerLabel() or ("turtle_" .. os.getComputerID())

local currentJob = nil
local status = "idle"
local progress = 0

local function send(msg)
    modem.transmit(CHANNEL, CHANNEL, protocol.encode(msg))
end

local function heartbeat()
    local fuel = turtle.getFuelLevel()
    send(protocol.heartbeat(id, status, currentJob and currentJob.jobId or nil, progress, fuel))
end

local function requestJob()
    send(protocol.jobRequest(id))
end

local function announceHello()
    send(protocol.hello(id))
end

local function reportError(message)
    send(protocol.errorMsg(id, message))
end

-- Event handler
local function handleMessage(_, side, ch, reply, message)
    if ch ~= CHANNEL then return end
    local data = protocol.decode(message)
    if not data or type(data) ~= "table" then return end
    if data.id and data.id ~= id then return end

    if data.type == "assign_job" then
        currentJob = data.job
    end
end

-- Background heartbeat
local function heartbeatLoop()
    while true do
        heartbeat()
        os.sleep(5)
    end
end

-- Mining loop
local function miningLoop()
    announceHello()

    while true do
        if not currentJob then
            status = "idle"
            progress = 0
            requestJob()
            os.sleep(3)
        else
            status = "mining"
            progress = 0
            local ok, err = pcall(function()
                lane_miner.mineLane(currentJob, function(p)
                    progress = p
                end)
            end)

            if not ok then
                status = "error"
                reportError(err)
                currentJob = nil
                os.sleep(5)
            else
                status = "finished"
                progress = 100
                send(protocol.jobDone(id, currentJob.jobId))
                currentJob = nil
                os.sleep(2)
            end
        end
    end
end

-- Main event loop
parallel.waitForAny(
    heartbeatLoop,
    miningLoop,
    function()
        while true do
            local ev = {os.pullEvent()}
            if ev[1] == "modem_message" then
                handleMessage(table.unpack(ev))
            end
        end
    end
)
