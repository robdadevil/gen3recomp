-- src/ui/game3/BattleRenderer.lua
local BattleRenderer = {}

local COLOR_HP_GREEN = {0.2, 0.8, 0.2}
local COLOR_HP_YELLOW = {0.9, 0.7, 0.1}
local COLOR_HP_RED    = {0.8, 0.2, 0.2}
local COLOR_BOX_BG    = {0.1, 0.1, 0.1, 0.85}

function BattleRenderer.new()
  local self = setmetatable({}, { __index = BattleRenderer })
  self.displayHpPlayer = 0
  self.displayHpEnemy  = 0
  return self
end

local function getHpBarColor(ratio)
  if ratio > 0.5 then return COLOR_HP_GREEN
  elseif ratio > 0.2 then return COLOR_HP_YELLOW
  else return COLOR_HP_RED end
end

function BattleRenderer:update(dt, playerMon, enemyMon)
  -- Smooth interpolation for HP bars
  if playerMon then
    self.displayHpPlayer = self.displayHpPlayer + (playerMon.currentHp - self.displayHpPlayer) * 8 * dt
  end
  if enemyMon then
    self.displayHpEnemy = self.displayHpEnemy + (enemyMon.currentHp - self.displayHpEnemy) * 8 * dt
  end
end

function BattleRenderer:drawHPBox(x, y, mon, displayHp, isPlayer)
  local ratio = math.max(0, math.min(1, displayHp / mon.maxHp))
  
  -- Outer Frame
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", x, y, 160, isPlayer and 42 or 32, 4, 4)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("line", x, y, 160, isPlayer and 42 or 32, 4, 4)

  -- Name & Level
  love.graphics.print(mon.name, x + 8, y + 4)
  love.graphics.print("Lv" .. mon.level, x + 115, y + 4)

  -- Status condition pill
  if mon.status and mon.status ~= "NONE" then
    love.graphics.setColor(0.9, 0.3, 0.3, 1)
    love.graphics.rectangle("fill", x + 8, y + 18, 28, 10, 2, 2)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(mon.status, x + 10, y + 17)
  end

  -- HP Bar background and fill
  local barX = x + 42
  local barY = y + 20
  love.graphics.setColor(0.2, 0.2, 0.2, 1)
  love.graphics.rectangle("fill", barX, barY, 105, 8)

  love.graphics.setColor(getHpBarColor(ratio))
  love.graphics.rectangle("fill", barX, barY, math.floor(105 * ratio), 8)

  -- Numerical readout (Player side only, GBA authentic)
  if isPlayer then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(math.floor(displayHp) .. "/" .. mon.maxHp, x + 85, y + 29)
  end
end

function BattleRenderer:draw(playerMon, enemyMon, messageText)
  love.graphics.setColor(1, 1, 1, 1)

  -- 1. Sprites
  if enemyMon and enemyMon.frontSprite then
    love.graphics.draw(enemyMon.frontSprite, 160, 20)
  end
  if playerMon and playerMon.backSprite then
    love.graphics.draw(playerMon.backSprite, 30, 90)
  end

  -- 2. HP Cards
  if enemyMon then self:drawHPBox(10, 10, enemyMon, self.displayHpEnemy, false) end
  if playerMon then self:drawHPBox(140, 100, playerMon, self.displayHpPlayer, true) end

  -- 3. Dialog Box
  if messageText and messageText ~= "" then
    love.graphics.setColor(COLOR_BOX_BG)
    love.graphics.rectangle("fill", 10, 150, 220, 40, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", 10, 150, 220, 40, 4, 4)
    love.graphics.print(messageText, 18, 160)
  end
end

return BattleRenderer
