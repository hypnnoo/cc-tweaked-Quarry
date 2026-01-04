-- dispatcher/config.lua
local config = {}

config.CHANNEL = 42069

-- EXACT chunk-sized quarry: 16 (X) × 16 (Z) × 200 (Y depth)
config.QUARRY = {
    width  = 16,   -- X
    depth  = 16,   -- Z
    height = 200,  -- layers down
}

-- Start with 1 lane/turtle while you tune it.
-- Later you can bump this up and spread turtles.
config.LANES = 1

function config.generateLaneJobs()
    local jobs = {}
    local laneWidth = math.floor(config.QUARRY.width / config.LANES)
    local remainder = config.QUARRY.width % config.LANES

    local x = 0
    for lane = 1, config.LANES do
        local w = laneWidth
        if lane == config.LANES then w = w + remainder end

        table.insert(jobs, {
            jobId   = "lane_" .. lane,
            lane    = lane,
            xOffset = x,                  -- blocks along X from turtle start
            width   = w,                  -- lane width
            depth   = config.QUARRY.depth,
            height  = config.QUARRY.height,
        })

        x = x + w
    end

    return jobs
end

return config
