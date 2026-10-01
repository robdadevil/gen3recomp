-- COMMENT OUT OR REMOVE:
-- InputAdapter = require("src.core.engine.InputAdapter")

-- ADD THIS MOCK OBJECT INSTEAD:
InputAdapter = {
    update = function(dt) end,
    keypressed = function(key) end,
    keyreleased = function(key) end,
    gamepadpressed = function(joystick, button) end,
    gamepadreleased = function(joystick, button) end,
    isDown = function(action) return false end
}
