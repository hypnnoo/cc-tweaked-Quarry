while true do
    for i=1,16 do
        turtle.select(i)
        turtle.suck()
    end
    for i=1,16 do
        turtle.select(i)
        turtle.drop()
    end
    sleep(120)
end
