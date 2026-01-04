-- turtle/inventory.lua
local inv = {}

-- items we NEVER dump (keep)
local keep = {
    ["minecraft:bucket"] = true
}

-- threshold: number of empty slots allowed before we say "full"
function inv.isFull(threshold)
    threshold = threshold or 2
    local empty = 0
    for s = 1, 16 do
        if turtle.getItemCount(s) == 0 then
            empty = empty + 1
        end
    end
    return empty <= threshold
end

-- Dump items into chest BEHIND the turtle
function inv.dumpToChest()
    -- face chest behind
    turtle.turnLeft()
    turtle.turnLeft()

    for s = 1, 16 do
        turtle.select(s)
        local d = turtle.getItemDetail()
        if d and not keep[d.name] then
            turtle.drop()
        end
    end

    -- face quarry again
    turtle.turnLeft()
    turtle.turnLeft()
    turtle.select(1)
end

return inv
