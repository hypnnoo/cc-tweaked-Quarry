-- turtle/inventory.lua
-- Inventory helper:
--  - isFull(thresholdEmpty)
--  - dumpToChest() behind the turtle
--  - keeps empty buckets
--  - NEW: drops junk blocks (cobble/andesite/netherrack/endstone) down into the quarry
--    instead of putting them into the chest.

local inv = {}

-- Items we NEVER dump (we keep these)
local keep = {
    ["minecraft:bucket"] = true,   -- keep empty buckets
}

-- Items we consider "junk" and drop into the quarry (downwards)
local junk = {
    ["minecraft:cobblestone"] = true,
    ["minecraft:andesite"]    = true,
    ["minecraft:netherrack"]  = true,
    ["minecraft:end_stone"]   = true,  -- vanilla name
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

-- Dump items:
-- 1) Junk blocks get dropped DOWN into the quarry (so they never hit the chest)
-- 2) Other non-kept items get dropped into the chest BEHIND the turtle
function inv.dumpToChest()
    ----------------------------------------------------------------
    -- Step 1: drop junk down into the mined area
    ----------------------------------------------------------------
    for s = 1, 16 do
        turtle.select(s)
        local d = turtle.getItemDetail()
        if d and junk[d.name] then
            -- Drop junk into the hole / quarry below
            turtle.dropDown()
        end
    end

    ----------------------------------------------------------------
    -- Step 2: drop good stuff into the chest behind
    ----------------------------------------------------------------
    turtle.turnLeft()
    turtle.turnLeft()  -- now facing chest behind

    for s = 1, 16 do
        turtle.select(s)
        local d = turtle.getItemDetail()
        if d then
            if not keep[d.name] and not junk[d.name] then
                -- Non-junk, non-keep → goes into chest
                turtle.drop()
            end
            -- keep[] (e.g. buckets) stay in inventory
            -- junk[] already dropped down in step 1
        end
    end

    -- Face back toward quarry
    turtle.turnLeft()
    turtle.turnLeft()
    turtle.select(1)
end

return inv
