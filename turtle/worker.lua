local protocol=require("protocol")
local miner=require("lane_miner")
local inv=require("inventory")
local nav=require("navigation")

local modem=peripheral.find("modem") or error("No modem")
modem.open(protocol.CHANNEL)

local id=os.getComputerLabel() or tostring(os.getComputerID())
local job=nil
local sx,sy,sz=gps.locate(5)

local function send(m)
    modem.transmit(protocol.CHANNEL,protocol.CHANNEL,protocol.encode(m))
end

send(protocol.hello(id))
for i = 1, 16 do
    turtle.select(i)
    turtle.refuel(1)
end
turtle.select(1)
while true do
    if not job then
        send(protocol.jobRequest(id))
        sleep(2)
    else
        local r=miner.mine(job,function(p)
            send(protocol.heartbeat(id,"mining",job.jobId,p,turtle.getFuelLevel()))
        end)

        if r=="FULL" then
            nav.returnToSurface(sx,sy,sz)
            inv.dumpToChest()
        else
            send(protocol.jobDone(id,job.jobId))
            job=nil
        end
    end

    local _,_,_,_,msg=os.pullEvent("modem_message")
    local d=protocol.decode(msg)
    if d and d.type=="assign_job" and d.id==id then
        job=d.job
    end
end

