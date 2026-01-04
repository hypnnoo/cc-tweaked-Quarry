local protocol = {}

protocol.CHANNEL = 42069

function protocol.encode(t) return textutils.serialize(t) end
function protocol.decode(s)
    local ok, r = pcall(textutils.unserialize, s)
    if ok then return r end
end

function protocol.hello(id) return {type="hello",id=id} end
function protocol.jobRequest(id) return {type="request_job",id=id} end
function protocol.jobAssign(id,job) return {type="assign_job",id=id,job=job} end
function protocol.jobDone(id,jid) return {type="job_done",id=id,jobId=jid} end
function protocol.errorMsg(id,msg) return {type="error",id=id,message=msg} end

function protocol.heartbeat(id,status,jobId,progress,fuel)
    return {
        type="heartbeat",
        id=id,
        status=status,
        jobId=jobId,
        progress=progress,
        fuel=fuel
    }
end

return protocol
