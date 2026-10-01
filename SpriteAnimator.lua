-- src/render/game3/SpriteAnimator.lua
local SpriteAnimator = {}
SpriteAnimator.__index = SpriteAnimator

function SpriteAnimator.new()
  local self = setmetatable({}, SpriteAnimator)
  self.animations = {}
  return self
end

function SpriteAnimator:registerPokemonSprite(speciesId, spriteSheet, isEmerald)
  local imgW, imgH = spriteSheet:getDimensions()
  local frameWidth = 64
  local frameHeight = 64

  local frames = {
    frame1 = love.graphics.newQuad(0, 0, frameWidth, frameHeight, imgW, imgH),
    frame2 = isEmerald and love.graphics.newQuad(64, 0, frameWidth, frameHeight, imgW, imgH) or nil
  }

  self.animations[speciesId] = {
    image = spriteSheet,
    frames = frames,
    isEmerald = isEmerald,
    timer = 0,
    currentFrame = 1
  }
end

function SpriteAnimator:update(dt)
  for _, anim in pairs(self.animations) do
    if anim.isEmerald and anim.frames.frame2 then
      anim.timer = anim.timer + dt
      if anim.timer >= 0.25 then
        anim.timer = anim.timer - 0.25
        anim.currentFrame = (anim.currentFrame == 1) and 2 or 1
      end
    end
  end
end

function SpriteAnimator:drawBattleSprite(speciesId, x, y, scale)
  local anim = self.animations[speciesId]
  if not anim then return end

  scale = scale or 1.0
  local quad = (anim.currentFrame == 1) and anim.frames.frame1 or anim.frames.frame2
  love.graphics.draw(anim.image, quad, x, y, 0, scale, scale)
end

return SpriteAnimator
