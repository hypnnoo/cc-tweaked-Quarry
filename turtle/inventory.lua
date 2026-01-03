-- turtle/inventory.lua
-- Simple inventory helper for turtles

local inventory = {}

-- Returns true if inventory is almost full
function inventory.isFull(threshold)
    threshold = threshold or 2  -- number of empty slots allowed
    local empty = 0
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then
            empty = empty + 1
        end
    end
    return empty <= threshold
end

-- Dump all items into chest behind turtle
function inventory.dumpToChest()
    turtle.turnLeft()
    turtle.turnLeft()

    for i = 1, 16 do
        turtle.select(i)
        turtle.drop()
    end

    turtle.turnLeft()
    turtle.turnLeft()
end

return inventory
