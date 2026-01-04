config.QUARRY = {
    width  = 16,
    depth  = 16,
    height = 200,
}

config.LANES = 4

function config.generateLaneJobs()
    local jobs = {}
    local totalWidth = config.QUARRY.width
    local lanes      = config.LANES

    local baseWidth = math.floor(totalWidth / lanes)  -- 4
    local remainder = totalWidth % lanes              -- 0 for 16/4

    for lane = 1, lanes do
        local w = baseWidth
        if lane == lanes then
            w = w + remainder
        end

        table.insert(jobs, {
            jobId   = "lane_" .. lane,
            lane    = lane,
            xOffset = 0,                  -- IMPORTANT: no sideways walk now
            width   = w,                  -- 4
            depth   = config.QUARRY.depth,
            height  = config.QUARRY.height,
        })
    end

    return jobs
end

