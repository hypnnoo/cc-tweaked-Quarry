-- dispatcher/config.lua

local config = {}

-- Radio
config.CHANNEL = 42069

-- Quarry definition (top layer), relative to turtles' starting line
-- Imagine turtles are lined up along X, all facing +Z into the quarry.
config.QUARRY = {
    width = 32,   -- total width across all lanes
    depth = 32,   -- how far forward to mine
    height = 60,  -- how many blocks down (optional, used only by lane miner)
}

-- Number of lanes / turtles you plan to use
config.LANES = 4

-- Simple lane generation: splits width evenly into LANES
function config.generateLaneJobs()
    local jobs = {}
    local laneWidth = math.floor(config.QUARRY.width / config.LANES)
    local remainder = config.QUARRY.width % config.LANES

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
            xOffset = x,
            width = w,
            depth = config.QUARRY.depth,
            height = config.QUARRY.height,
        })
        x = x + w
    end

    return jobs
end

return config
