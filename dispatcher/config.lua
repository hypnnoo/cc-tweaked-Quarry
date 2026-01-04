-- dispatcher/config.lua

local config = {}

config.CHANNEL = 42069

config.QUARRY = {
    width  = 16,   -- left/right (X)
    depth  = 16,   -- forward (Z)
    height = 200,  -- down (Y)
}

config.LANES = 4

function config.generateLaneJobs()
    local jobs = {}
    local laneWidth = math.floor(config.QUARRY.width / config.LANES)  -- 16/4 = 4

    for lane = 1, config.LANES do
        local jobId = "lane_" .. lane

        table.insert(jobs, {
            jobId   = jobId,
            lane    = lane,
            xOffset = 0,                    -- no sideways walk; placement defines lane
            width   = laneWidth,            -- 4-wide strip
            depth   = config.QUARRY.depth,  -- 16 forward
            height  = config.QUARRY.height, -- 200 layers down
        })
    end

    return jobs
end

return config
