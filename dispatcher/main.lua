-- dispatcher/main.lua
-- Monitor UI with per-turtle progress bar and fuel bar + clickable buttons

local protocol = require("protocol")
local config   = require("config")

local modem = peripheral.find("modem") or error("No modem attached")
modem.open(config.CHANNEL)

local monitor = peripheral.find("monitor")
if monitor then
    term.redirect(monitor)
    pcall(function() monitor.setTextScale(0.5) end)
end

local W, H = term.getSize()
local BTN_Y = H - 1

local turtles = {}           -- id -> {status,fuel,progress,jobId,lastSeen}
local jobs    = config.generateLaneJobs()
local paused  = false

local function send(msg)
    modem.transmit(config.CHANNEL, config.CHANNEL, protocol.encode(msg))
end

local function drawBar(x,y,width,percent,color)
    percent = math.max(0, math.min(100, percent or 0))
    local filled = math.floor((percent / 100) * width + 0.5)

    term.setCursorPos(x,y)
    term.setBackgroundColor(colors.gray)
    term.write(string.rep(" ", width))

    if filled > 0 then
        term.setCursorPos(x,y)
        term.setBackgroundColor(color)
        term.write(string.rep(" ", filled))
    end

    term.setBackgroundColor(colors.black)
end

local function drawButtons()
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1, BTN_Y)
    term.clearLine()

    term.setCursorPos(2, BTN_Y)
    term.setTextColor(colors.green)
    term.write("[ Reload ]")

    term.setCursorPos(14, BTN_Y)
    term.setTextColor(colors.red)
    term.write("[ Clear ]")

    term.setCursorPos(26, BTN_Y)
    term.setTextColor(paused and colors.red or colors.green)
    term.write(paused and "[ Resume ]" or "[ Pause ]")
end

local function draw()
    term.setBackgroundColor(colors.black)
    term.clear()

    term.setCursorPos(2,1)
    term.setTextColor(colors.yellow)
    term.write("Quarry Dispatcher")

    local row = 3
    for id,t in pairs(turtles) do
        if row + 1 >= BTN_Y then break end

        -- Line 1: ID + status + numeric fuel
        term.setCursorPos(2,row)
        term.setTextColor(colors.white)
        term.write(string.format(
            "%-12s %-10s Fuel:%5d",
            id,
            tostring(t.status or "?"),
            tonumber(t.fuel or 0) or 0
        ))

        -- Line 2: progress bar + fuel bar
        local progress = tonumber(t.progress or 0) or 0
        local fuel     = tonumber(t.fuel or 0) or 0

        -- fuel pct: assume 0..100000, clamp
        local fuelPct = math.min(100, math.floor((fuel / 100000) * 100))

        -- progress bar (24 wide), fuel bar (12 wide)
        drawBar(2, row+1, 24, progress, (progress >= 100 and colors.green or colors.lime))

        term.setCursorPos(28, row+1)
        term.setTextColor(colors.white)
        term.write("P:" .. string.format("%3d%%", progress))

        drawBar(36, row+1, 12, fuelPct,
            (fuelPct < 20 and colors.red) or (fuelPct < 50 and colors.yellow) or colors.green)
        term.setCursorPos(49, row+1)
        term.write("F:" .. string.format("%3d%%", fuelPct))

        row = row + 3
    end

    drawButtons()
end

local function click(x,y)
    if y ~= BTN_Y then return end

    if x >= 2 and x <= 10 then
        jobs = config.generateLaneJobs()
    elseif x >= 14 and x <= 22 then
        jobs = {}
    elseif x >= 26 and x <= 35 then
        paused = not paused
    end

    draw()
end

local function assign(id)
    if paused or #jobs == 0 then return end
    local job = table.remove(jobs, 1)
    send(protocol.jobAssign(id, job))
end

while true do
    local e = {os.pullEvent()}
    local ev = e[1]

    if ev == "monitor_touch" then
        local _,_,x,y = table.unpack(e)
        click(x,y)

    elseif ev == "modem_message" then
        local _,_,ch,_,msg = table.unpack(e)
        if ch ~= config.CHANNEL then goto continue end

        local d = protocol.decode(msg)
        if not d or not d.id then goto continue end

        local t = turtles[d.id] or {}
        turtles[d.id] = t

        if d.type == "hello" then
            t.status = "online"

        elseif d.type == "heartbeat" then
            t.status   = d.status or t.status
            t.jobId    = d.jobId or t.jobId
            t.progress = d.progress or 0
            t.fuel     = d.fuel or 0
            t.lastSeen = os.epoch("local")

        elseif d.type == "request_job" then
            t.status = "requesting"
            assign(d.id)

        elseif d.type == "job_done" then
            t.status   = "idle"
            t.jobId    = nil
            t.progress = 100
        end

        draw()
        ::continue::
    end
end

