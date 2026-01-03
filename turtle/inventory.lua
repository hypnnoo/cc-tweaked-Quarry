-- turtle/inventory.lua
-- Improved inventory helper for turtles:
--  - selective unload using a whitelist (keeps ores/valuable items)
--  - safe chest detection (down, back, front)
--  - DRY_RUN mode for simulations

local inventory = {}

-- DRY_RUN: when true, actions that would move/drop items are only printed.
inventory.DRY_RUN = false

-- Default whitelist of valuable items (common vanilla ores). You can override with setWhitelist().
local defaultWhitelist = {
    ["minecraft:coal_ore"] = true,
    ["minecraft:iron_ore"] = true,
    ["minecraft:gold_ore"] = true,
    ["minecraft:diamond_ore"] = true,
    ["minecraft:emerald_ore"] = true,
    ["minecraft:redstone_ore"] = true,
    ["minecraft:lapis_ore"] = true,
    ["minecraft:nether_quartz"] = true,
    ["minecraft:nether_gold_ore"] = true,
}

inventory.keepWhitelist = defaultWhitelist

function inventory.setWhitelist(tbl)
    inventory.keepWhitelist = tbl or {}
end

-- Heuristic: treat anything explicitly whitelisted as valuable; otherwise treat "ore" in name as valuable.
local function isValuableDetail(detail)
    if not detail or not detail.name then return false end
    if inventory.keepWhitelist[detail.name] then return true end
    if string.find(detail.name:lower(), "ore") then return true end
    -- keep ingots, gems, dusts (common valuable suffixes)
    if string.find(detail.name:lower(), "ingot") or string.find(detail.name:lower(), "gem") or string.find(detail.name:lower(), "dust") then
        return true
    end
    return false
end

function inventory.isValuable(detail)
    return isValuableDetail(detail)
end

-- Returns true if inventory is almost full (threshold = number of empty slots allowed)
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

local function turnAround()
    turtle.turnLeft()
    turtle.turnLeft()
end

-- Attempt to detect best side to unload into (prioritize down, then back, then front)
local function detectUnloadSide()
    if peripheral.getType("down") then
        return "down"
    elseif peripheral.getType("back") then
        return "back"
    elseif peripheral.getType("front") then
        return "front"
    else
        return nil
    end
end

-- Dump non-valuable items into adjacent inventory (down/back/front) if present.
-- If no peripheral detected, fall back to drop in front.
function inventory.dumpToChest()
    if inventory.DRY_RUN then
        print("[DRY_RUN] would dump non-valuable items to chest (selective).")
        return
    end

    local side = detectUnloadSide()

    -- If we need to drop to back, we'll turn around, drop, then turn back.
    local usingBack = (side == "back")

    if usingBack then
        turnAround()
    end

    for slot = 1, 16 do
        turtle.select(slot)
        local detail = turtle.getItemDetail(slot)
        if detail then
            if not isValuableDetail(detail) then
                -- drop into chosen side
                if side == "down" then
                    turtle.dropDown()
                else
                    -- front or fallback
                    turtle.drop()
                end
            end
        end
    end

    if usingBack then
        turnAround()
    end

    turtle.select(1)
end

-- Force dump everything (useful for refuelers or cleanup)
function inventory.forceDumpAll()
    if inventory.DRY_RUN then
        print("[DRY_RUN] would force-dump all items.")
        return
    end

    local side = detectUnloadSide()
    local usingBack = (side == "back")
    if usingBack then turnAround() end

    for i = 1, 16 do
        turtle.select(i)
        if side == "down" then
            turtle.dropDown()
        else
            turtle.drop()
        end
    end

    if usingBack then turnAround() end
    turtle.select(1)
end

return inventory
