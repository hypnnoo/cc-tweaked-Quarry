local config = {}

config.CHANNEL = 42069

config.QUARRY = {
    width = 16,
    depth = 16,
    height = 200 -- SAFE FOR ATM10
}

config.LANES = 4

function config.generateLaneJobs()
    local jobs = {}
    local laneWidth = config.QUARRY.width / config.LANES
    local x = 0

    for i = 1, config.LANES do
        table.insert(jobs,{
            jobId="lane_"..i,
            xOffset=x,
            width=laneWidth,
            depth=config.QUARRY.depth,
            height=config.QUARRY.height
        })
        x = x + laneWidth
    end
    return jobs
end

return config
