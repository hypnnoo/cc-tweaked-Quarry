-- shared/protocol.lua
local p = {}

p.CHANNEL = 42069

function p.encode(t) return textutils.serialize(t) end
function p.decode(s)
    local ok, r = pcall(textutils.unserialize, s)
    if ok then return r end
end

function p.hello(id)         return {type="hello",        id=id} end
function p.jobRequest(id)    return {type="request_job",  id=id} end
function p.jobAssign(id,job) return {type="assign_job",   id=id, job=job} end
function p.jobDone(id,j)     return {type="job_done",     id=id, jobId=j} end
function p.errorMsg(id,m)    return {type="error",        id=id, message=m} end

function p.heartbeat(id,status,jobId,progress,fuel)
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

return p
