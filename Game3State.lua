-- src/states/Game3State.lua
local GameVersion      = require("src.core.GameVersion")
local SaveManager      = require("src.core.game3.SaveManager")
local SaveWriter       = require("src.core.game3.SaveWriter")
local PokemonUnpacker  = require("src.core.game3.PokemonUnpacker")
local PokemonData      = require("src.core.game3.PokemonData")
local TextDecoder      = require("src.core.game3.TextDecoder")
local ScriptEngine     = require("src.core.game3.ScriptEngine")
local BattleEngine     = require("src.core.game3.BattleEngine")
local WarpManager      = require("src.core.game3.WarpManager")
local MapRenderer      = require("src.render.game3.MapRenderer")
local SpriteAnimator   = require("src.render.game3.SpriteAnimator")
local BattleUI         = require("src.ui.game3.BattleUI")
local AudioEngine      = require("src.audio.game3.AudioEngine")

local Game3State = {}
Game3State.__index = Game3State

function Game3State.new()
  local self = setmetatable({}, Game3State)
  
  -- Core Engine Modes: "OVERWORLD", "BATTLE", "MENU"
  self.mode = "OVERWORLD"
  
  -- Initialize Subsystems
  GameVersion.set("emerald")
  self.mapRenderer   = MapRenderer.new()
  self.warpManager   = WarpManager.new(self.mapRenderer)
  self.scriptEngine  = ScriptEngine.new({}, {})
  self.battleEngine  = nil
  self.battleUI      = BattleUI.new()
  self.spriteAnim    = SpriteAnimator.new()
  self.audio         = AudioEngine.new()

  -- Player State
  self.player = {
    gridX = 10,
    gridY = 15,
    pixelX = 160,
    pixelY = 240,
    party = {}
  }

  return self
end

function Game3State:loadSaveFile(rawBinaryData)
  local saveInfo, err = SaveManager.parseSaveFile(rawBinaryData)
  if not saveInfo then
    print("Error loading Gen 3 save file: " .. tostring(err))
    return false
  end

  print("Successfully loaded active slot: " .. saveInfo.activeSlot)
  -- Process active save sector data...
  return true
end

function Game3State:startBattle(enemyMon, isDouble)
  self.mode = "BATTLE"
  self.battleEngine = BattleEngine.new(isDouble)
  
  -- Queue opening battle BGM and play enemy cry
  self.audio:playBGM("assets/audio/bgm/battle_wild.ogg")
  if enemyMon.species then
    self.audio:playCry(enemyMon.species)
  end
end

function Game3State:update(dt)
  if self.mode == "OVERWORLD" then
    self.warpManager:update(dt)
    
    -- Check map warps under player position
    local warp = self.warpManager:checkWarp(self.player.gridX, self.player.gridY)
    if warp then
      self.warpManager:triggerWarp(warp, self.player)
    end

    -- Process script execution queue
    self.scriptEngine:step()

  elseif self.mode == "BATTLE" then
    self.spriteAnim:update(dt)
    -- Process battle turns if choices are locked
  end
end

function Game3State:draw()
  if self.mode == "OVERWORLD" then
    self.mapRenderer:drawMap(self.currentMap, self.player.pixelX - 120, self.player.pixelY - 80)
    self.warpManager:drawOverlay()

  elseif self.mode == "BATTLE" then
    -- Draw Battle HUD and options
    if #self.player.party > 0 and self.enemyMon then
      self.battleUI:drawHUD(self.player.party[1], self.enemyMon)
      self.battleUI:drawMenu(260, 160)
    end
  end
end

function Game3State:keypressed(key)
  if self.mode == "OVERWORLD" then
    if key == "space" or key == "return" then
      self.scriptEngine:advanceText()
    end
  elseif self.mode == "BATTLE" then
    if key == "up" then
      self.battleUI.selectedOption = math.max(1, self.battleUI.selectedOption - 2)
    elseif key == "down" then
      self.battleUI.selectedOption = math.min(4, self.battleUI.selectedOption + 2)
    elseif key == "left" or key == "right" then
      local alt = (self.battleUI.selectedOption % 2 == 1) and 1 or -1
      self.battleUI.selectedOption = self.battleUI.selectedOption + alt
    end
  end
end

return Game3State
