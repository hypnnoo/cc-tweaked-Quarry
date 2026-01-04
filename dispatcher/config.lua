-- dispatcher/config.lua

local config = {}

-- Radio
config.CHANNEL = 42069

-- Quarry definition: 16 x 16 area, 200 blocks down
-- Turtles are lined up along X, all facing +Z into the quarry.
config.QUARRY = {
    width  = 16,   -- total width across all lanes (X)
    depth  = 16,   -- how far forward to mine (Z)
    height = 200,  -- how many blocks down to mine (Y)
}

-- Number of lanes / turtles (set to 2–4 depending on how many miners you run)
config.LANES = 4

-- Generate lane jobs splitting width evenly across lanes
function config.generateLaneJobs()
    local jobs = {}
    local totalWidth = config.QUARRY.width
    local lanes      = config.LANES

    local baseWidth = math.floor(totalWidth / lanes)
    local remainder = totalWidth % lanes

    local x = 0
    for lane = 1, lanes do
        local w = baseWidth
        if lane == lanes then
            w = w + remainder
        end

        local jobId = "lane_" .. lane

        table.insert(jobs, {
            jobId   = jobId,
            lane    = lane,
            xOffset = x,                  -- turtle moves xOffset blocks along X to reach its lane
            width   = w,                  -- lane width
            depth   = config.QUARRY.depth,
            height  = config.QUARRY.height,
        })

        x = x + w
    end

    return jobs
end

return config
