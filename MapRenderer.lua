-- src/render/game3/MapRenderer.lua
local MapRenderer = {}
MapRenderer.__index = MapRenderer

function MapRenderer.new()
  local self = setmetatable({}, MapRenderer)
  self.tileCache = {}
  self.paletteBanks = {}
  return self
end

function MapRenderer:loadTileset(tilesetImage, blockData)
  self.tilesetImage = tilesetImage
  self.blockData = blockData -- Contains sub-tile mappings for each 16x16 metatile
end

function MapRenderer:drawMap(mapData, cameraX, cameraY)
  if not self.tilesetImage or not mapData then return end

  love.graphics.push()
  love.graphics.translate(-cameraX, -cameraY)

  local tileSize = 16
  for y = 0, mapData.height - 1 do
    for x = 0, mapData.width - 1 do
      local tileIndex = mapData.tiles[y * mapData.width + x + 1]
      local posX = x * tileSize
      local posY = y * tileSize

      -- Draw 16x16 metatile composed of four 8x8 GBA sub-tiles
      self:drawMetaTile(tileIndex, posX, posY)
    end
  end

  love.graphics.pop()
end

function MapRenderer:drawMetaTile(blockId, x, y)
  -- Placeholder Quad drawing logic for the 16x16 block from the loaded image
  local quad = self.tileCache[blockId]
  if not quad and self.tilesetImage then
    local imgW, imgH = self.tilesetImage:getDimensions()
    local cols = math.floor(imgW / 16)
    local qx = (blockId % cols) * 16
    local qy = math.floor(blockId / cols) * 16
    quad = love.graphics.newQuad(qx, qy, 16, 16, imgW, imgH)
    self.tileCache[blockId] = quad
  end

  if quad then
    love.graphics.draw(self.tilesetImage, quad, x, y)
  end
end

return MapRenderer
