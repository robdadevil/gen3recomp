-- src/core/game3/WarpManager.lua
local WarpManager = {}
WarpManager.__index = WarpManager

function WarpManager.new(mapRenderer)
  local self = setmetatable({}, WarpManager)
  self.mapRenderer = mapRenderer
  self.currentMapId = nil
  self.warps = {}
  self.isTransitioning = false
  self.fadeAlpha = 0
  return self
end

function WarpManager:setMapWarps(warpList)
  self.warps = warpList -- Array of {x, y, destMap, destX, destY}
end

function WarpManager:checkWarp(playerX, playerY)
  if self.isTransitioning then return nil end

  for _, warp in ipairs(self.warps) do
    if warp.x == playerX and warp.y == playerY then
      return warp
    end
  end
  return nil
end

function WarpManager:triggerWarp(warp, player)
  self.isTransitioning = true
  self.targetWarp = warp
  self.playerRef = player
end

function WarpManager:update(dt)
  if not self.isTransitioning then return end

  -- Fade out
  self.fadeAlpha = math.min(1.0, self.fadeAlpha + dt * 2.5)
  if self.fadeAlpha >= 1.0 and self.targetWarp then
    -- Teleport player and switch map
    self.playerRef.gridX = self.targetWarp.destX
    self.playerRef.gridY = self.targetWarp.destY
    self.currentMapId = self.targetWarp.destMap
    
    self.targetWarp = nil -- Signal fade in
  elseif self.fadeAlpha > 0 and not self.targetWarp then
    -- Fade in
    self.fadeAlpha = math.max(0.0, self.fadeAlpha - dt * 2.5)
    if self.fadeAlpha == 0 then
      self.isTransitioning = false
    end
  end
end

function WarpManager:drawOverlay()
  if self.fadeAlpha > 0 then
    love.graphics.setColor(0, 0, 0, self.fadeAlpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1, 1)
  end
end

return WarpManager
