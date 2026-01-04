-- shared/protocol.lua
-- Simple message helpers for dispatcher <-> turtles

local protocol = {}

protocol.CHANNEL = 42069  -- radio channel

function protocol.encode(tbl)
    return textutils.serialize(tbl)
end

function protocol.decode(str)
    local ok, result = pcall(textutils.unserialize, str)
    if ok then return result else return nil end
end

function protocol.hello(id)
    return {
        type = "hello",
        id   = id,
    }
end

function protocol.jobRequest(id)
    return {
        type = "request_job",
        id   = id,
    }
end

function protocol.jobAssign(id, job)
    return {
        type = "assign_job",
        id   = id,
        job  = job,
    }
end

function protocol.jobDone(id, jobId)
    return {
        type  = "job_done",
        id    = id,
        jobId = jobId,
    }
end

function protocol.heartbeat(id, status, jobId, progress, fuel)
    return {
        type     = "heartbeat",
        id       = id,
        status   = status,
        jobId    = jobId,
        progress = progress,
        fuel     = fuel,
        time     = os.epoch("local"),
    }
end

function protocol.errorMsg(id, message)
    return {
        type    = "error",
        id      = id,
        message = message,
    }
end

return protocol
