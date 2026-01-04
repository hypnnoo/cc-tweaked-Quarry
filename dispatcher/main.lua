local protocol = require("protocol")
local config = require("config")

local modem = peripheral.find("modem") or error("No modem")
modem.open(config.CHANNEL)

local monitor = peripheral.find("monitor")
if monitor then
    term.redirect(monitor)
    pcall(function() monitor.setTextScale(0.5) end)
end

local turtles = {}
local jobs = config.generateLaneJobs()
local paused = false
local W,H = term.getSize()
local BTN_Y = H-1

local function send(m)
    modem.transmit(config.CHANNEL,config.CHANNEL,protocol.encode(m))
end

local function draw()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(2,1)
    term.setTextColor(colors.yellow)
    term.write("Quarry Dispatcher")

    local y=3
    for id,t in pairs(turtles) do
        term.setCursorPos(2,y)
        term.setTextColor(colors.white)
        term.write(id.." | "..(t.status or "?").." | Fuel "..(t.fuel or 0))
        y=y+1
    end

    term.setCursorPos(2,BTN_Y)
    term.setTextColor(colors.green)
    term.write("[ Reload ]")
    term.setCursorPos(14,BTN_Y)
    term.setTextColor(colors.red)
    term.write("[ Clear ]")
    term.setCursorPos(26,BTN_Y)
    term.setTextColor(paused and colors.red or colors.green)
    term.write(paused and "[ Resume ]" or "[ Pause ]")
end

local function click(x,y)
    if y~=BTN_Y then return end
    if x>=2 and x<=10 then
        jobs=config.generateLaneJobs()
    elseif x>=14 and x<=22 then
        jobs={}
    elseif x>=26 and x<=35 then
        paused=not paused
    end
    draw()
end

local function assign(id)
    if paused or #jobs==0 then return end
    local j=table.remove(jobs,1)
    send(protocol.jobAssign(id,j))
end

draw()

while true do
    local e={os.pullEvent()}
    if e[1]=="monitor_touch" then
        click(e[3],e[4])

    elseif e[1]=="modem_message" then
        local d=protocol.decode(e[5])
        if d and d.id then
            turtles[d.id]=turtles[d.id] or {}
            local t=turtles[d.id]
            if d.type=="hello" then t.status="online"
            elseif d.type=="heartbeat" then t.status=d.status t.fuel=d.fuel
            elseif d.type=="request_job" then assign(d.id)
            elseif d.type=="job_done" then t.status="idle" end
            draw()
        end
    end
end

