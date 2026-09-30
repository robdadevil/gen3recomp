function love.resize(w, h)
    -- Recalculate layout dimensions when screen rotates or resizes
    if updateMenuLayout then
        updateMenuLayout(w, h)
    end
end
