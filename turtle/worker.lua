local protocol = require("protocol")
local miner = require("lane_miner")
local inventory = require("inventory")
local nav = require("navigation")

local modem = peripheral.find("modem") or error("No modem")
modem.open(protocol.CHANNEL)

local id = os.getComputerLabel() or tostring(os.getComputerID())
local job = nil

local function send(t)
    modem.transmit(protocol.CHANNEL, protocol.CHANNEL, protocol.encode(t))
end

local function loop()
    send(protocol.hello(id))
    while true do
        if not job then
            send(protocol.jobRequest(id))
            sleep(2)
        else
            miner.mineLane(job,function(p)
                send(protocol.heartbeat(id,"mining",job.jobId,p,turtle.getFuelLevel()))
            end)
            send(protocol.jobDone(id,job.jobId))
            job = nil
        end
    end
end

local function listen()
    while true do
        local _,_,_,_,msg = os.pullEvent("modem_message")
        local d = protocol.decode(msg)
        if d and d.type=="assign_job" and d.id==id then
            job = d.job
        end
    end
end

parallel.waitForAny(loop, listen)
