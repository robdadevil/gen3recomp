-- src/ui/game3/BattleUI.lua
local BattleUI = {}
BattleUI.__index = BattleUI

function BattleUI.new()
  local self = setmetatable({}, BattleUI)
  self.selectedOption = 1 -- 1: Fight, 2: Bag, 3: Pokemon, 4: Run
  self.selectedMove = 1
  self.state = "MAIN" -- MAIN, MOVES, TEXT
  return self
end

function BattleUI:drawHPBar(x, y, width, height, currentHp, maxHp)
  local pct = math.max(0, math.min(1, currentHp / maxHp))
  
  -- Color shifts: Green (>50%), Yellow (>20%), Red (<=20%)
  if pct > 0.5 then
    love.graphics.setColor(0.2, 0.8, 0.2)
  elseif pct > 0.2 then
    love.graphics.setColor(0.9, 0.8, 0.1)
  else
    love.graphics.setColor(0.9, 0.2, 0.2)
  end

  love.graphics.rectangle("fill", x, y, math.floor(width * pct), height)
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("line", x, y, width, height)
end

function BattleUI:drawHUD(playerMon, enemyMon)
  -- Enemy Box
  love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
  love.graphics.rectangle("fill", 20, 20, 200, 50)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(enemyMon.name .. " Lv." .. enemyMon.level, 30, 25)
  self:drawHPBar(30, 45, 180, 8, enemyMon.currentHp, enemyMon.stats.hp)

  -- Player Box
  love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
  love.graphics.rectangle("fill", 260, 160, 200, 60)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(playerMon.name .. " Lv." .. playerMon.level, 270, 165)
  self:drawHPBar(270, 185, 180, 8, playerMon.currentHp, playerMon.stats.hp)
  love.graphics.print(playerMon.currentHp .. "/" .. playerMon.stats.hp, 370, 198)
end

function BattleUI:drawMenu(x, y)
  love.graphics.setColor(0.1, 0.1, 0.2, 0.9)
  love.graphics.rectangle("fill", x, y, 200, 80)
  love.graphics.setColor(1, 1, 1)

  local opts = {"FIGHT", "BAG", "POKÉMON", "RUN"}
  for i, opt in ipairs(opts) do
    local ox = x + ((i - 1) % 2) * 100 + 15
    local oy = y + math.floor((i - 1) / 2) * 35 + 15
    if i == self.selectedOption then
      love.graphics.print("> " .. opt, ox - 10, oy)
    else
      love.graphics.print(opt, ox, oy)
    end
  end
end

return BattleUI
