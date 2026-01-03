-- shared/protocol.lua
-- Simple message helpers for dispatcher <-> turtles

local protocol = {}

protocol.CHANNEL = 42069  -- change if you want a private channel

function protocol.encode(tbl)
    return textutils.serialize(tbl)
end

function protocol.decode(str)
    local ok, result = pcall(textutils.unserialize, str)
    if ok then return result else return nil end
end

-- Message constructors

function protocol.hello(id)
    return {
        type = "hello",
        id = id,
    }
end

function protocol.heartbeat(id, status, jobId, progress, fuel)
    return {
        type = "heartbeat",
        id = id,
        status = status,     -- "idle", "mining", "error"
        jobId = jobId,
        progress = progress, -- 0-100
        fuel = fuel,
        time = os.epoch("local"),
    }
end

function protocol.jobRequest(id)
    return {
        type = "request_job",
        id = id,
    }
end

function protocol.jobAssign(id, job)
    return {
        type = "assign_job",
        id = id,
        job = job, -- {jobId, xOffset, width, depth}
    }
end

function protocol.jobDone(id, jobId)
    return {
        type = "job_done",
        id = id,
        jobId = jobId,
    }
end

function protocol.errorMsg(id, message)
    return {
        type = "error",
        id = id,
        message = message,
    }
end

return protocol
