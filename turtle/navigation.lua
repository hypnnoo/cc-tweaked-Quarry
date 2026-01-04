local n={}

function n.returnToSurface(_,y,_)
    local _,cy=gps.locate()
    while cy>y do
        if turtle.detectDown() then turtle.digDown() end
        turtle.down()
        _,cy=gps.locate()
    end
end

return n

