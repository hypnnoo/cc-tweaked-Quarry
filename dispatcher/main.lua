-- dispatcher/main.lua

local basalt = require("basalt")
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

-- GUI setup
local main = basalt.getMainFrame()
local w, h = term.getSize()
main:setSize(w, h)
main:setBackground(colors.gray)
main:setForeground(colors.white)

main:addLabel()
    :setText("Quarry Dispatcher")
    :setPosition(2, 1)
    :setForeground(colors.yellow)

local listTurtles = main:addList()
    :setPosition(2, 3)
    :setSize(32, h - 6)

local listFuel = main:addList()
    :setPosition(35, 3)
    :setSize(15, h - 6)

local listLog = main:addList()
    :setPosition(52, 3)
    :setSize(w - 53, h - 6)

local btnReload = main:addButton()
    :setText("Reload Jobs")
    :setPosition(2, h - 2)
    :setSize(12, 1)

local btnClear = main:addButton()
    :setText("Clear Jobs")
    :setPosition(16, h - 2)
    :setSize(12, 1)

-- Utility
local function log(msg)
    listLog:addItem(os.date("%H:%M:%S") .. " " .. msg)
end

local function refreshTurtleList()
    listTurtles:clear()
    listFuel:clear()

    for id, t in pairs(turtles) do
        local status = t.status or "unknown"
        local line = ("%s | %s | job:%s | %d%%"):format(
            id,
            status,
            t.jobId or "-",
            t.progress or 0
        )
        listTurtles:addItem(line)

        local fuel = t.fuel or 0
        local fuelStr = ("%s: %d"):format(id, fuel)
        if fuel < 500 then
            fuelStr = fuelStr .. " (LOW)"
        end
        listFuel:addItem(fuelStr)
    end
end

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
    refreshTurtleList()
end

-- Button handlers
btnReload:onClick(function()
    jobsQueue = config.generateLaneJobs()
    log("Jobs reloaded")
end)

btnClear:onClick(function()
    jobsQueue = {}
    activeJobs = {}
    log("Cleared jobs (no new assignments)")
end)

-- Event handlers
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

    refreshTurtleList()
end

-- Background task: timeout detection
main:addThread():start(function()
    while true do
        local now = os.epoch("local")
        for id, t in pairs(turtles) do
            if t.lastSeen and now - t.lastSeen > 30000 then -- 30 seconds
                t.status = "timeout"
            end
        end
        refreshTurtleList()
        os.sleep(5)
    end
end)

-- Basalt event loop integration
main:onEvent(function(self, event, ...)
    if event == "modem_message" then
        handleMessage(event, ...)
    end
end)

log("Dispatcher started. Waiting for turtles...")

basalt.run()
