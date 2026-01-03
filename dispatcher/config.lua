-- dispatcher/config.lua

local config = {}

-- Radio
config.CHANNEL = 42069

-- Quarry definition: 16 x 16 area, 253 blocks down
-- Turtles are lined up along X, all facing +Z into the quarry.
config.QUARRY = {
    width = 16,   -- total width across all lanes (X)
    depth = 16,   -- how far forward to mine (Z)
    height = 253, -- how many blocks down to mine (Y)
}

-- Number of lanes / turtles
config.LANES = 4

-- Split 16 blocks width into 4 lanes of 4 blocks each
function config.generateLaneJobs()
    local jobs = {}
    local laneWidth = math.floor(config.QUARRY.width / config.LANES) -- 4
    local remainder = config.QUARRY.width % config.LANES              -- 0

    local x = 0
    for lane = 1, config.LANES do
        local w = laneWidth
        if lane == config.LANES then
            w = w + remainder
        end
        local jobId = ("lane_%d"):format(lane)
        table.insert(jobs, {
            jobId = jobId,
            lane = lane,
            xOffset = x,                -- turtle moves xOffset blocks along X to reach its lane
            width = w,                  -- lane width (4 each)
            depth = config.QUARRY.depth,
            height = config.QUARRY.height,
        })
        x = x + w
    end

    return jobs
end

return config
