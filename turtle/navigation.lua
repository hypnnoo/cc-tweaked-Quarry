-- turtle/navigation.lua
-- Simple GPS-based vertical return helper (if you ever want it)

local nav = {}

function nav.returnToSurface(_, targetY, _)
    local _, y = gps.locate()
    if not y then return end

    while y > targetY do
        if turtle.detectDown() then turtle.digDown() end
        turtle.down()
        _, y = gps.locate()
    end
end

return nav

