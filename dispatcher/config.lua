local c = {}

c.CHANNEL = 42069

c.QUARRY = {
    width = 16,
    depth = 16,
    height = 120
}

c.LANES = 4

function c.generateLaneJobs()
    local jobs = {}
    local w = c.QUARRY.width / c.LANES
    local x = 0
    for i=1,c.LANES do
        table.insert(jobs,{
            jobId="lane_"..i,
            xOffset=x,
            width=w,
            depth=c.QUARRY.depth,
            height=c.QUARRY.height
        })
        x = x + w
    end
    return jobs
end

return c
