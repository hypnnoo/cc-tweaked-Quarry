-- navigation.lua
-- GPS-based return-to-surface navigation

local nav = {}

-- Get current GPS position safely
local function getPos()
    local x, y, z = gps.locate(2)
    if not x then
        error("GPS unavailable")
    end
    return x, y, z
end

-- Move vertically to target Y
local function moveToY(targetY)
    local _, y = getPos()
    while y < targetY do
        while turtle.detectUp() do turtle.digUp() end
        turtle.up()
        _, y = getPos()
    end
    while y > targetY do
        while turtle.detectDown() do turtle.digDown() end
        turtle.down()
        _, y = getPos()
    end
end

-- Move horizontally to target X/Z
local function moveToXZ(targetX, targetZ)
    local x, _, z = getPos()

    -- Move X
    if targetX > x then
        while turtle.turnRight() do
            local nx, _, _ = getPos()
            if nx > x then break end
        end
    elseif targetX < x then
        while turtle.turnLeft() do
            local nx, _, _ = getPos()
            if nx < x then break end
        end
    end
    while true do
        local cx, _, _ = getPos()
        if cx == targetX then break end
        if turtle.detect() then turtle.dig() end
        turtle.forward()
    end

    -- Move Z
    local _, _, z2 = getPos()
    if targetZ > z2 then
        turtle.turnRight()
    else
        turtle.turnLeft()
    end
    while true do
        local _, _, cz = getPos()
        if cz == targetZ then break end
        if turtle.detect() then turtle.dig() end
        turtle.forward()
    end
end

-- Public function
function nav.returnToSurface(startX, startY, startZ)
    -- Step 1: go up to surface Y
    moveToY(startY)

    -- Step 2: move horizontally back to start X/Z
    moveToXZ(startX, startZ)
end

return nav
