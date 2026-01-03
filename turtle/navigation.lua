-- turtle/navigation.lua
-- GPS-based return-to-surface navigation

local nav = {}

local function getPos()
    local x, y, z = gps.locate(2)
    if not x then
        error("GPS unavailable")
    end
    return x, y, z
end

local function moveVertical(targetY)
    local _, y = getPos()
    while y < targetY do
        while turtle.detectUp() do turtle.digUp() sleep(0.1) end
        turtle.up()
        _, y = getPos()
    end
    while y > targetY do
        while turtle.detectDown() do turtle.digDown() sleep(0.1) end
        turtle.down()
        _, y = getPos()
    end
end

-- naive heading management:
-- we always move in axis-aligned steps using GPS comparisons

local function moveAxis(axis, target)
    while true do
        local x, y, z = getPos()
        local curr = (axis == "x") and x or z
        if curr == target then break end

        -- decide desired direction
        local forwardBetter
        -- try forward
        if turtle.detect() then turtle.dig() end
        local ok = turtle.forward()
        if not ok then
            -- cannot go forward; try turning and stepping, but keep it simple:
            turtle.turnLeft()
            turtle.turnLeft()
            if turtle.detect() then turtle.dig() end
            turtle.forward()
            turtle.turnLeft()
            turtle.turnLeft()
        end
    end
end

-- Simplified: we only guarantee vertical return; horizontal return can be rough.
-- Because exact heading computation would need more careful tracking.
-- Here we just focus on reaching surface Y.
function nav.returnToSurface(startX, startY, startZ)
    moveVertical(startY)
    -- You can extend horizontal movement if you want exact start X/Z.
end

return nav
