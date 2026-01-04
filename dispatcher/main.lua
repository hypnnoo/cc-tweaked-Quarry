-- dispatcher/main.lua
-- Compact UI for a small 3x4 monitor wall
-- Features:
--  - Shows up to 2 turtles per page
--  - Progress bar + fuel bar
--  - Low fuel warning
--  - Tap monitor to change page / toggle pause

local protocol = require("protocol")
local config   = require("config")

local modem = peripheral.find("modem") or error("No modem attached")
modem.open(config.CHANNEL)

local monitor = peripheral.find("monitor")
if not monitor then error("No monitor connected") end

-- Small but readable text scale for a tiny wall
pcall(function() monitor.setTextScale(1.5) end)
term.redirect(monitor)

local W, H = term.getSize()  -- should be small, like ~24x9
local turtles = {}           -- id -> {status,fuel,progress,jobId,lastSeen}
local jobs    = config.generateLaneJobs()
local paused  = false
local page    = 1
local perPage = 2            -- 2 turtles per page

------------------------------------------------------------
-- Helpers
------------------------------------------------------------

local function send(msg)
    modem.transmit(config.CHANNEL, config.CHANNEL, protocol.encode(msg))
end

local function sortedIds()
    local ids = {}
    for id in pairs(turtles) do
        table.insert(ids, id)
    end
    table.sort(ids)
    return ids
end

local function drawBar(x, y, width, percent, color)
    percent = math.max(0, math.min(100, percent or 0))
    local filled = math.floor((percent / 100) * width + 0.5)

    -- background
    term.setCursorPos(x, y)
    term.setBackgroundColor(colors.gray)
    term.write(string.rep(" ", width))

    if filled > 0 then
        term.setCursorPos(x, y)
        term.setBackgroundColor(color)
        term.write(string.rep(" ", filled))
    end

    term.setBackgroundColor(colors.black)
end

local function draw()
    term.setBackgroundColor(colors.black)
    term.clear()

    --------------------------------------------------
    -- HEADER
    --------------------------------------------------
    term.setCursorPos(1, 1)
    term.setTextColor(colors.yellow)
    local title = paused and "Quarry [PAUSE]" or "Quarry"
    term.write(title)

    --------------------------------------------------
    -- BODY: 2 turtles max per page
    --------------------------------------------------
    local ids = sortedIds()
    local totalPages = math.max(1, math.ceil(#ids / perPage))
    if page > totalPages then page = totalPages end
    if page < 1 then page = 1 end

    local startIndex = (page - 1) * perPage + 1
    local y = 2

    for i = startIndex, math.min(startIndex + perPage - 1, #ids) do
        local id = ids[i]
        local t  = turtles[id]

        local p = tonumber(t.progress or 0) or 0
        local f = tonumber(t.fuel or 0) or 0
        local fuelPct = math.min(100, math.floor((f / 100000) * 100))

        -- Name + low fuel indicator
        term.setCursorPos(1, y)
        term.setTextColor(colors.white)
        term.clearLine()
        local label = string.sub(id, 1, W - 6)
        term.write(label)

        if fuelPct < 20 then
            term.setTextColor(colors.red)
            term.write(" LOW")
        end

        y = y + 1

        -- Progress + fuel bars on same line (split screen)
        local barWidth = math.floor(W / 2) - 1
        local fuelX    = W - barWidth + 1

        -- Progress bar (left)
        drawBar(1, y, barWidth, p,
            (p >= 100 and colors.green) or colors.lime)

        -- Fuel bar (right)
        local fuelColor =
            (fuelPct < 20 and colors.red) or
            (fuelPct < 50 and colors.orange) or
            colors.green

        drawBar(fuelX, y, barWidth, fuelPct, fuelColor)

        y = y + 1
        if y >= H then break end
    end

    --------------------------------------------------
    -- FOOTER / TOUCH CONTROLS
    --------------------------------------------------
    term.setCursorPos(1, H)
    term.setTextColor(colors.cyan)
    term.setBackgroundColor(colors.black)
    term.clearLine()

    -- Footer legend:
    -- Left 1/3:  Prev page
    -- Mid  1/3:  Pause/Resume
    -- Right1/3:  Next page
    local footer = string.format("< Pg %d/%d > ", page, totalPages)
    if paused then
        footer = footer .. "P:PAU"
    else
        footer = footer .. "P:RUN"
    end
    term.write(string.sub(footer, 1, W))
end

local function assign(id)
    if paused or #jobs == 0 then return end
    local job = table.remove(jobs, 1)
    send(protocol.jobAssign(id, job))
end

------------------------------------------------------------
-- Touch: left/mid/right to prev/pause-next
------------------------------------------------------------
local function handleTouch(_, _, x, _)
    local third = math.floor(W / 3)

    if x <= third then
        -- prev page
        page = page - 1
    elseif x <= third * 2 then
        -- toggle pause (only affects job assignment)
        paused = not paused
        -- Note: turtles will finish current jobs; no auto-return yet
    else
        -- next page
        page = page + 1
    end

    draw()
end

------------------------------------------------------------
-- Modem loop: updates turtle info and assigns jobs
------------------------------------------------------------
local function modemLoop()
    while true do
        local _, _, ch, _, msg = os.pullEvent("modem_message")
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
            t.progress = d.progress or t.progress or 0
            t.fuel     = d.fuel or t.fuel or 0
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

------------------------------------------------------------
-- Main
------------------------------------------------------------
draw()
parallel.waitForAny(
    modemLoop,
    function()
        while true do
            handleTouch(os.pullEvent("monitor_touch"))
        end
    end
)
