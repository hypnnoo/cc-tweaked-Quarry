local i = {}

local keep = {
    ["minecraft:bucket"] = true
}

function i.isFull(th)
    th = th or 1
    local empty = 0
    for s = 1, 16 do
        if turtle.getItemCount(s) == 0 then
            empty = empty + 1
        end
    end
    return empty <= th
end

-- Dump items into a chest BEHIND the turtle
function i.dumpToChest()
    -- turn around to face the chest behind
    turtle.turnLeft()
    turtle.turnLeft()

    for s = 1, 16 do
        turtle.select(s)
        local d = turtle.getItemDetail()
        if d and not keep[d.name] then
            turtle.drop()   -- drop into chest behind
        end
    end

    -- face back toward the quarry
    turtle.turnLeft()
    turtle.turnLeft()
    turtle.select(1)
end

return i
