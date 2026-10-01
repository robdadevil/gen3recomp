-- Example snippet inside your PauseMenu UI component
local PauseMenu = {}

PauseMenu.options = {
  { label = "Pokedex",   action = function() openPokedex() end },
  { label = "Pokemon",   action = function() openParty() end },
  { label = "Save",      action = function() performSave() end },
  { label = "Change ROM", action = function()
      -- Calls main.lua game selector menu
      if showGameSelector then showGameSelector() end
  end }
}

function PauseMenu:onSelect(index)
  if self.options[index] then
    self.options[index].action()
  end
end

return PauseMenu
