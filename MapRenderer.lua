-- src/core/engine/MapRenderer.lua
local MapRenderer = {}
MapRenderer.__index = MapRenderer

function MapRenderer.new(tileSize)
  local self = setmetatable({}, MapRenderer)
  self.tileSize = tileSize or 16 -- GBA standard 16x16 tiles
  self.mapWidth = 0
  self.mapHeight = 0
  self.layers = { bg = {}, fg = {}, collision = {} }
  self.tilesetImage = nil
  self.quads = {}
  
  -- Camera Position
  self.cameraX = 0
  self.cameraY = 0
  return self
end

function MapRenderer:loadTileset(imagePath, tileW, tileH)
  self.tilesetImage = love.graphics.newImage(imagePath)
  self.tilesetImage:setFilter("nearest", "nearest")
  
  local imgW, imgH = self.tilesetImage:getDimensions()
  local cols = math.floor(imgW / tileW)
  local rows = math.floor(imgH / tileH)

  self.quads = {}
  local id = 1
  for r = 0, rows - 1 do
    for c = 0, cols - 1 do
      self.quads[id] = love.graphics.newQuad(
        c * tileW, r * tileH, tileW, tileH, imgW, imgH
      )
      id = id + 1
    end
  end
end

function MapRenderer:loadMapData(mapData)
  self.mapWidth = mapData.width
  self.mapHeight = mapData.height
  self.layers.bg = mapData.layers.bg or {}
  self.layers.fg = mapData.layers.fg or {} -- Foreground/Overhead trees
  self.layers.collision = mapData.layers.collision or {}
end

function MapRenderer:isSolid(tileX, tileY)
  if tileX < 1 or tileX > self.mapWidth or tileY < 1 or tileY > self.mapHeight then
    return true -- Out of bounds is solid
  end
  local index = (tileY - 1) * self.mapWidth + tileX
  return self.layers.collision[index] == 1
end

function MapRenderer:updateCamera(targetX, targetY, viewportW, viewportH, dt)
  -- Center camera on target tile coordinates
  local destX = (targetX * self.tileSize) - (viewportW / 2) + (self.tileSize / 2)
  local destY = (targetY * self.tileSize) - (viewportH / 2) + (self.tileSize / 2)

  -- Clamp camera inside map boundaries
  destX = math.max(0, math.min(destX, (self.mapWidth * self.tileSize) - viewportW))
  destY = math.max(0, math.min(destY, (self.mapHeight * self.tileSize) - viewportH))

  -- Smooth camera lerp
  self.cameraX = self.cameraX + (destX - self.cameraX) * 10 * dt
  self.cameraY = self.cameraY + (destY - self.cameraY) * 10 * dt
end

function MapRenderer:drawLayer(layerName)
  local layer = self.layers[layerName]
  if not layer or not self.tilesetImage then return end

  love.graphics.push()
  love.graphics.translate(-math.floor(self.cameraX), -math.floor(self.cameraY))

  for y = 1, self.mapHeight do
    for x = 1, self.mapWidth do
      local idx = (y - 1) * self.mapWidth + x
      local tileId = layer[idx]
      if tileId and tileId > 0 and self.quads[tileId] then
        love.graphics.draw(
          self.tilesetImage,
          self.quads[tileId],
          (x - 1) * self.tileSize,
          (y - 1) * self.tileSize
        )
      end
    end
  end

  love.graphics.pop()
end

return MapRenderer
