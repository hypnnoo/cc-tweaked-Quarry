local i = {}

local keep = {
    ["minecraft:bucket"]=true
}

function i.isFull(th)
    th=th or 1
    local e=0
    for s=1,16 do
        if turtle.getItemCount(s)==0 then e=e+1 end
    end
    return e<=th
end

function i.dumpToChest()
    for s=1,16 do
        turtle.select(s)
        local d=turtle.getItemDetail()
        if d and not keep[d.name] then turtle.drop() end
    end
    turtle.select(1)
end

return i
