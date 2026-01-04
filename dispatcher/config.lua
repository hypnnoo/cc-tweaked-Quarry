local config = {}

config.CHANNEL = 42069

-- 16 × 16 × 200
config.QUARRY = {
    width  = 16,   -- X size
    depth  = 16,   -- Z size
    height = 200,  -- downwards layers
}

-- For now, I’d strongly suggest 1 lane while we nail geometry
config.LANES = 1

function config.generateLaneJobs()
    local jobs = {}
    local laneWidth = config.QUARRY.width / config.LANES
    local x = 0
    for lane = 1, config.LANES do
        table.insert(jobs, {
            jobId  = "lane_" .. lane,
            lane   = lane,
            xOffset= x,
            width  = laneWidth,
            depth  = config.QUARRY.depth,
            height = config.QUARRY.height,
        })
        x = x + laneWidth
    end
    return jobs
end

return config
