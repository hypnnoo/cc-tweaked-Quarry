-- turtle/navigation.lua
-- GPS-based return-to-surface helper (currently not used by miner)

local nav = {}

function nav.returnToSurface(targetX, targetY, targetZ)
    local x, y, z = gps.locate(3)
    if not x then
        error("GPS unavailable")
    end

    -- Simple "go up until target Y" behavior
    while y < targetY do
        if turtle.detectUp() then turtle.digUp() end
        turtle.up()
        x, y, z = gps.locate(3)
    end
end

return nav
