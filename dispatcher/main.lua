-- dispatcher/main.lua
-- Native term-based GUI dispatcher (static layout)

local protocol = require("protocol")
local config = require("config")

local modem = peripheral.find("modem")
if not modem then
    error("No modem attached to dispatcher computer")
end
modem.open(config.CHANNEL)

-- State
local turtles = {}      -- [id] = {status, jobId, progress, fuel, lastSeen}
local jobsQueue = config.generateLaneJobs()  -- pending jobs
local activeJobs = {}   -- [jobId] = turtleId
local logLines = {}     -- simple log buffer

-- Layout (static)
local termW, termH = term.getSize()
local turtlePanelW = 32
local fuelPanelW   = 16
local logPanelW    = termW - turtlePanelW - fuelPanelW - 3 -- borders
local headerY      = 1
local contentTop   = 3
local contentBottom = termH - 2

-- Logging
local function log(msg)
    local line = os.date("%H:%M:%S") .. " " .. msg
    table.insert(logLines, line)
    if #logLines > (contentBottom - contentTop + 1) then
        table.remove(logLines, 1)
    end
end

-- Job assignment
local function assignJobToTurtle(turtleId)
    if #jobsQueue == 0 then
        log("No jobs left to assign")
        return
    end
    local job = table.remove(jobsQueue, 1)
    activeJobs[job.jobId] = turtleId

    local msg = protocol.jobAssign(turtleId, job)
    modem.transmit(config.CHANNEL, config.CHANNEL, protocol.encode(msg))
    log(("Assigned %s to %s"):format(job.jobId, turtleId))

    turtles[turtleId] = turtles[turtleId] or {}
    turtles[turtleId].status = "assigned"
    turtles[turtleId].jobId = job.jobId
end

-- Rendering helpers
local function drawBox(x1, y1, x2, y2, title)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    for y = y1, y2 do
        term.setCursorPos(x1, y)
        term.write(string.rep(" ", x2 - x1 + 1))
    end

    -- top border
    term.setCursorPos(x1, y1)
    term.write("+" .. string.rep("-", x2 - x1 - 1) .. "+")
    -- bottom border
    term.setCursorPos(x1, y2)
    term.write("+" .. string.rep("-", x2 - x1 - 1) .. "+")
    -- sides
    for y = y1 + 1, y2 - 1 do
        term.setCursorPos(x1, y)
        term.write("|")
        term.setCursorPos(x2, y)
        term.write("|")
    end

    if title then
        term.setCursorPos(x1 + 2, y1)
        term.setTextColor(colors.yellow)
        term.write(title)
        term.setTextColor(colors.white)
    end
end

local function drawHeader()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.setCursorPos(2, headerY)
    term.clearLine()
    term.write("Quarry Dispatcher - Static GUI")
end

local function drawButtons()
    local y = termH - 1
    term.setBackgroundColor(colors.black)
    term.setCursorPos(2, y)
    term.setTextColor(colors.white)
    term.clearLine()
    term.setCursorPos(2, y)
    term.write("[R]eload Jobs   [C]lear Jobs")
end

local function drawTurtlePanel()
    local x1 = 1
    local x2 = turtlePanelW
    local y1 = contentTop - 1
    local y2 = contentBottom
    drawBox(x1, y1, x2, y2, "Turtles")

    local row = contentTop
    for id, t in pairs(turtles) do
        if row > contentBottom then break end
        local status = t.status or "unknown"
        local line = ("%s | %s"):format(id, status)
        term.setCursorPos(x1 + 1, row)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.gray)
        term.write(line:sub(1, turtlePanelW - 2))
        row = row + 1

        if row > contentBottom then break end
        local jobStr = ("job:%s %3d%%"):format(t.jobId or "-", t.progress or 0)
        term.setCursorPos(x1 + 1, row)
        term.write(jobStr:sub(1, turtlePanelW - 2))
        row = row + 1
    end
end

local function drawFuelPanel()
    local x1 = turtlePanelW + 1
    local x2 = turtlePanelW + fuelPanelW
    local y1 = contentTop - 1
    local y2 = contentBottom
    drawBox(x1, y1, x2, y2, "Fuel")

    local row = contentTop
    for id, t in pairs(turtles) do
        if row > contentBottom then break end
        local fuel = t.fuel or 0
        local label = ("%s: %d"):format(id, fuel)
        term.setCursorPos(x1 + 1, row)
        term.setBackgroundColor(colors.gray)
        if fuel < 500 then
            term.setTextColor(colors.red)
        else
            term.setTextColor(colors.green)
        end
        term.write(label:sub(1, fuelPanelW - 2))
        row = row + 1
    end
end

local function drawLogPanel()
    local x1 = turtlePanelW + fuelPanelW + 1
    local x2 = termW
    local y1 = contentTop - 1
    local y2 = contentBottom
    drawBox(x1, y1, x2, y2, "Log")

    local maxLines = contentBottom - contentTop + 1
    local start = math.max(1, #logLines - maxLines + 1)
    local row = contentTop

    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    for i = start, #logLines do
        if row > contentBottom then break end
        term.setCursorPos(x1 + 1, row)
        term.write(logLines[i]:sub(1, logPanelW - 2))
        row = row + 1
    end
end

local function redraw()
    term.setBackgroundColor(colors.black)
    term.clear()
    drawHeader()
    drawButtons()
    drawTurtlePanel()
    drawFuelPanel()
    drawLogPanel()
end

-- Message handling
local function handleMessage(_, side, ch, reply, message)
    if ch ~= config.CHANNEL then return end
    local data = protocol.decode(message)
    if not data or type(data) ~= "table" then return end

    local id = data.id
    if not id then return end

    turtles[id] = turtles[id] or {}
    turtles[id].lastSeen = os.epoch("local")

    if data.type == "hello" then
        turtles[id].status = "hello"
        log("Hello from " .. id)

    elseif data.type == "heartbeat" then
        turtles[id].status = data.status or turtles[id].status
        turtles[id].jobId = data.jobId or turtles[id].jobId
        turtles[id].progress = data.progress or 0
        turtles[id].fuel = data.fuel or 0

    elseif data.type == "request_job" then
        turtles[id].status = "requesting_job"
        assignJobToTurtle(id)

    elseif data.type == "job_done" then
        if activeJobs[data.jobId] == id then
            activeJobs[data.jobId] = nil
        end
        turtles[id].status = "idle"
        turtles[id].jobId = nil
        turtles[id].progress = 0
        log(("Job %s done by %s"):format(data.jobId, id))

    elseif data.type == "error" then
        turtles[id].status = "error"
        log(("Error from %s: %s"):format(id, data.message or ""))
    end

    redraw()
end

-- Timeout checker
local function timeoutLoop()
    while true do
        local now = os.epoch("local")
        for id, t in pairs(turtles) do
            if t.lastSeen and now - t.lastSeen > 30000 then -- 30 seconds
                t.status = "timeout"
            end
        end
        redraw()
        sleep(5)
    end
end

-- Input handler (keyboard only for simplicity)
local function inputLoop()
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "modem_message" then
            handleMessage(event, p1, p2, p3)
        elseif event == "char" then
            if p1 == "r" or p1 == "R" then
                jobsQueue = config.generateLaneJobs()
                log("Jobs reloaded")
                redraw()
            elseif p1 == "c" or p1 == "C" then
                jobsQueue = {}
                activeJobs = {}
                log("Cleared jobs (no new assignments)")
                redraw()
            end
        end
    end
end

-- Start
redraw()
log("Dispatcher started. Waiting for turtles...")
redraw()

parallel.waitForAny(timeoutLoop, inputLoop)
