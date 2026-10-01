-- COMMENT OUT OR REMOVE:
-- SwitchDiagnostics = require("src.core.engine.SwitchDiagnostics")

-- ADD THIS MOCK OBJECT:
SwitchDiagnostics = {
    init = function() end,
    update = function(dt) end,
    draw = function() end,
    log = function(msg) end,
    getReport = function() return {} end
}
