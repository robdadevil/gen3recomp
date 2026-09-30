-- main.lua
-- Native LÖVE2D Port & Custom Engine Driver for Gen 3 Pokémon.
-- Integrates Viewport Manager, Cross-Platform Input, Map Rendering, Save Management,
-- Save Editor tools, Engine State Routing, Custom GBA Cartridge ROM Selector, and Orientation Support.

--------------------------------------------------------------------------------
-- 1. REQUIRES & MODULE IMPORTS (WITH SAFE FALLBACK STUBS)
--------------------------------------------------------------------------------
local function safeRequire(path)
  local ok, mod = pcall(require, path)
  return ok and mod or nil
end

local ViewportManager     = safeRequire("src.core.engine.ViewportManager")
local InputAdapter        = safeRequire("src.core.engine.InputAdapter")
local MapRenderer         = safeRequire("src.core.engine.MapRenderer")
local SaveSystem          = safeRequire("src.core.engine.SaveSystem")
local SwitchDiagnostics   = safeRequire("src.debug.SwitchDiagnostics")
local PadHints            = safeRequire("src.core.PadHints") or { windowMinimized = function() return false end }
local LaunchOptions       = safeRequire("src.core.LaunchOptions") or { pollURI = function() return nil end, resolveRequest = function() return {} end }
local NxDisplay           = safeRequire("src.core.NxDisplay") or { sync = function() end }
local PlatformHooks       = safeRequire("src.core.PlatformHooks") or { update = function() end, quitToLauncher = function() return false end }
local HostDisplay         = safeRequire("src.core.HostDisplay") or { update = function() end, beginFrame = function() end, endFrame = function() end }
local GameViewport        = safeRequire("src.render.GameViewport") or { reset = function() end }
local SessionLifecycle    = safeRequire("src.core.SessionLifecycle") or { endGameSession = function() end, endMountedSession = function() end, endEditorSession = function() end, endProcess = function() end }

local BattleRenderer      = pcall(require, "src.ui.game3.BattleRenderer") and require("src.ui.game3.BattleRenderer") or nil

--------------------------------------------------------------------------------
-- FALLBACK ENGINE STUBS (Prevents crashes if source files are missing on disk)
--------------------------------------------------------------------------------
ViewportManager = ViewportManager or {
  init = function(w, h) end,
  updateScale = function() end,
  attach = function() end,
  detach = function() end,
  getScale = function() return 1 end
}

InputAdapter = InputAdapter or {
  init = function() end,
  updateKey = function(k, s) end,
  handleTouch = function() end,
  drawTouchControls = function() end
}

SwitchDiagnostics = SwitchDiagnostics or {
  init = function() end,
  update = function(dt) end,
  draw = function() end,
  log = function(m) end,
  logLuaError = function(msg, trace) return false end,
  maybeFlush = function() end,
  probeAssets = function() end,
  onJoystickEvent = function() end,
  onFocus = function() end
}

MapRenderer = MapRenderer or {
  new = function()
    return {
      loadMapData = function() end,
      drawLayer = function() end
    }
  end
}

SaveSystem = SaveSystem or {
  buildSaveData = function() return {} end,
  save = function() return true end,
  load = function() return {} end
}

--------------------------------------------------------------------------------
-- 2. GLOBAL STATE & UTILITIES
--------------------------------------------------------------------------------
local emergencyQuitTimer = 0
local cachedJoysticks = nil
local joystickCacheAge = 1

local editorMode = os.getenv("POKEPORT_EDITOR") == "1" or POKEPORT_EDITOR_MODE == true
local launchedIntoGame = false
local RELAUNCH_MARKER = "relaunch_to_launcher.txt"
local launchOptionsSuppressed = false
local quitToLauncher = false

local Game, EditorApp, Importer, TouchEditor, Studio, Prelaunch
local launcherSplash
local battleRenderer
local map
local pendingLauncherReturn

local player = { name = "Ruby", x = 5, y = 5, facing = "down", money = 3000 }
local party = {}

local autopilot
local driverCo
local speedOverride = tonumber(os.getenv("POKEPORT_SPEED"))
local mouseTouch = os.getenv("POKEPORT_TOUCH") == "1"

local onlineClient, onlineClientResolved
local function onlineClientModule()
  if onlineClientResolved then return onlineClient end
  onlineClientResolved = true
  local ok, mod = pcall(require, "src.online.Client")
  if ok and type(mod) == "table" and type(mod.update) == "function" then
    onlineClient = mod
  end
  return onlineClient
end

local function scriptedIterations()
  if not (autopilot or driverCo) then return 1 end
  local speed = Game and Game.driverSpeed or speedOverride
  local GameSpeed = safeRequire("src.core.GameSpeed")
  if GameSpeed and GameSpeed.clamp then
    return math.max(1, math.floor(GameSpeed.clamp(speed)))
  end
  return 1
end

local function applySavedOrientation()
  local ok, savedOptions = pcall(function()
    return require("src.core.SaveData").loadOptions()
  end)
  if not ok or type(savedOptions) ~= "table" then savedOptions = {} end
  pcall(function()
    require("src.core.Orientation").applyOptions(savedOptions)
  end)
end

-- -----------------------------------------------------------------------------
-- POKÉMON-THEMED CARTRIDGE ROM SELECTOR
-- -----------------------------------------------------------------------------
local gameMenuState = {
  active = false,
  selectedIndex = 1,
  pulseTimer = 0,
  games = {
    { id = "ruby",      name = "RUBY",      code = "AGB-AXVE-USA", color = {0.82, 0.12, 0.15}, accent = {0.95, 0.35, 0.35} },
    { id = "sapphire",  name = "SAPPHIRE",  code = "AGB-AXPE-USA", color = {0.12, 0.28, 0.82}, accent = {0.35, 0.55, 0.95} },
    { id = "emerald",   name = "EMERALD",   code = "AGB-BPEE-USA", color = {0.08, 0.62, 0.28}, accent = {0.25, 0.88, 0.45} },
    { id = "firered",   name = "FIRERED",   code = "AGB-BPRE-USA", color = {0.92, 0.38, 0.05}, accent = {1.00, 0.60, 0.20} },
    { id = "leafgreen", name = "LEAFGREEN", code = "AGB-BPGE-USA", color = {0.22, 0.72, 0.18}, accent = {0.45, 0.92, 0.38} },
  }
}

local function showGameSelector()
  gameMenuState.active = true
  if Game then
    SessionLifecycle.endGameSession(Game)
    Game = nil
  end
  Importer = nil
end

local function drawPokemonTitle(x, y, scale)
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(scale, scale)

  local text = "Gen3ReComp"
  local font = love.graphics.getFont()
  local textW = font:getWidth(text)
  local textH = font:getHeight()
  local originX = textW / 2
  local originY = textH / 2

  -- Outer Dark Blue Outline
  love.graphics.setColor(0.10, 0.18, 0.45, 1)
  for ox = -4, 4 do
    for oy = -4, 4 do
      if ox*ox + oy*oy <= 16 then
        love.graphics.print(text, -originX + ox, -originY + oy)
      end
    end
  end

  -- Inner Cyan/Sky Blue Shadow Accent
  love.graphics.setColor(0.25, 0.60, 0.95, 1)
  for ox = -2, 2 do
    for oy = -2, 2 do
      love.graphics.print(text, -originX + ox, -originY + oy)
    end
  end

  -- Golden Yellow Core Text
  love.graphics.setColor(1.00, 0.82, 0.10, 1)
  love.graphics.print(text, -originX, -originY)

  love.graphics.pop()
end

local function drawGBACartridge(x, y, w, h, game, isSelected, pulseTimer)
  love.graphics.push()
  
  -- Selection pop/scale animation
  if isSelected then
    local offset = math.sin(pulseTimer * 6) * 3
    y = y - 4 + offset
  end

  -- Cartridge Outer Body
  local r, g, b = unpack(game.color)
  love.graphics.setColor(r, g, b, 1)
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)

  -- Top Notch / Grip Ridge
  love.graphics.setColor(r * 0.7, g * 0.7, b * 0.7, 1)
  love.graphics.rectangle("fill", x + 12, y, w - 24, 6, 2, 2)
  love.graphics.setColor(r * 1.2 > 1 and 1 or r * 1.2, g * 1.2 > 1 and 1 or g * 1.2, b * 1.2 > 1 and 1 or b * 1.2, 0.3)
  love.graphics.rectangle("fill", x + 2, y + 2, w - 4, 3, 2, 2)

  -- Cartridge Label Area
  local labelMarginX = 14
  local labelMarginY = 12
  local labelW = w - (labelMarginX * 2)
  local labelH = h - (labelMarginY * 2) + 2

  love.graphics.setColor(0.94, 0.94, 0.96, 1)
  love.graphics.rectangle("fill", x + labelMarginX, y + labelMarginY, labelW, labelH, 4, 4)

  -- Label Accent Strip
  local ar, ag, ab = unpack(game.accent)
  love.graphics.setColor(ar, ag, ab, 1)
  love.graphics.rectangle("fill", x + labelMarginX, y + labelMarginY, labelW, 10, 4, 4)
  love.graphics.rectangle("fill", x + labelMarginX, y + labelMarginY + 6, labelW, 4)

  -- Label Text
  love.graphics.setColor(0.1, 0.1, 0.15, 1)
  love.graphics.print("POKÉMON", x + labelMarginX + 8, y + labelMarginY + 13)
  
  love.graphics.setColor(ar * 0.8, ag * 0.8, ab * 0.8, 1)
  love.graphics.print(game.name, x + labelMarginX + 8, y + labelMarginY + 27)

  love.graphics.setColor(0.5, 0.5, 0.5, 1)
  love.graphics.print(game.code, x + labelMarginX + 8, y + labelMarginY + labelH - 14)

  -- Selection Glow / Border Accent
  if isSelected then
    love.graphics.setLineWidth(3)
    love.graphics.setColor(1.00, 0.85, 0.20, 0.9 + math.sin(pulseTimer * 8) * 0.1)
    love.graphics.rectangle("line", x - 3, y - 3, w + 6, h + 6, 8, 8)
    love.graphics.setLineWidth(1)
  else
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
  end

  love.graphics.pop()
end

local function drawGameSelector()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local isPortrait = h > w

  -- Retro Dark Background
  love.graphics.clear(0.06, 0.07, 0.11)

  -- Background Decorative Grid
  love.graphics.setColor(0.12, 0.14, 0.22, 0.4)
  local gridSize = 24
  for gx = 0, w, gridSize do love.graphics.line(gx, 0, gx, h) end
  for gy = 0, h, gridSize do love.graphics.line(0, gy, w, gy) end

  -- Header Title Area
  local titleY = isPortrait and 45 or 32
  drawPokemonTitle(w / 2, titleY, isPortrait and 1.3 or 1.1)

  -- Help / Subtitle
  love.graphics.setColor(0.7, 0.75, 0.85, 0.9)
  love.graphics.printf("SELECT A CARTRIDGE TO LOAD", 0, titleY + (isPortrait and 32 or 24), w, "center")

  love.graphics.setColor(0.45, 0.50, 0.60, 0.8)
  love.graphics.printf("D-Pad/Arrows: Choose  |  A / Enter: Insert  |  F8: Import ROM", 0, h - (isPortrait and 30 or 20), w, "center")

  -- Layout Cartridges
  gameMenuState.pulseTimer = gameMenuState.pulseTimer + love.timer.getDelta()

  if isPortrait then
    -- Vertical Stack for Portrait Mobile
    local cartW = math.min(w * 0.82, 320)
    local cartH = 64
    local startY = titleY + 70
    local spacing = 12

    for i, game in ipairs(gameMenuState.games) do
      local cartX = (w - cartW) / 2
      local cartY = startY + (i - 1) * (cartH + spacing)
      drawGBACartridge(cartX, cartY, cartW, cartH, game, i == gameMenuState.selectedIndex, gameMenuState.pulseTimer)
    end
  else
    -- Horizontal Grid / Shelf for Landscape Mode
    local cartW = 160
    local cartH = 110
    local totalW = (#gameMenuState.games * cartW) + ((#gameMenuState.games - 1) * 16)
    local startX = (w - totalW) / 2
    local cartY = titleY + 65

    for i, game in ipairs(gameMenuState.games) do
      local cartX = startX + (i - 1) * (cartW + 16)
      drawGBACartridge(cartX, cartY, cartW, cartH, game, i == gameMenuState.selectedIndex, gameMenuState.pulseTimer)
    end
  end
end

local function processAndImportRom(filePath)
  local ok, RomImporter = pcall(require, "src.import.RomImporter")
  if not ok then print("[ROM IMPORTER] RomImporter module not found."); return end

  local ext = filePath:match("%.([^%.]+)$"):lower()
  print("[ROM IMPORTER] Processing: " .. filePath)

  if ext == "zip" then
    print("[ZIP EXTRACTOR] Extracting archive...")
    local okZip = pcall(function() love.filesystem.mount(filePath, "zip_temp") end)
    if okZip then
      for _, file in ipairs(love.filesystem.getDirectoryItems("zip_temp")) do
        local subExt = file:match("%.([^%.]+)$"):lower()
        if subExt == "gba" or subExt == "gbc" or subExt == "gb" then
          filePath = "zip_temp/" .. file
          break
        end
      end
    end
  end

  Importer = RomImporter.new(function(version, cartId, opts)
    Importer = nil
    gameMenuState.active = false
    bootGame(version or "emerald", cartId, opts)
  end, {
    launcher = false,
    forceImport = true
  })

  if Importer and Importer.startPath then
    Importer:startPath(filePath)
  end
end

--------------------------------------------------------------------------------
-- 3. EMERGENCY QUIT & CRASH HANDLING
--------------------------------------------------------------------------------
local function checkEmergencyQuit(dt)
  local held = false
  joystickCacheAge = joystickCacheAge + (dt or 0.016)
  if love.joystick and love.joystick.getJoysticks then
    if not cachedJoysticks or joystickCacheAge >= 1 then
      cachedJoysticks = love.joystick.getJoysticks()
      joystickCacheAge = 0
    end
    for _, j in ipairs(cachedJoysticks) do
      if j:isGamepad() then
        local start = j:isGamepadDown("start")
        local selectBtn = j:isGamepadDown("back") or j:isGamepadDown("guide")
        if start and selectBtn then held = true; break end
      else
        local bCount = j:getButtonCount()
        local s1 = (bCount >= 7 and j:isDown(7)) or (bCount >= 9 and j:isDown(9))
        local s2 = (bCount >= 8 and j:isDown(8)) or (bCount >= 10 and j:isDown(10))
        if s1 and s2 then held = true; break end
      end
    end
  end

  if love.keyboard and love.keyboard.isDown then
    if (love.keyboard.isDown("escape") and love.keyboard.isDown("return"))
        or (love.keyboard.isDown("lalt") and love.keyboard.isDown("f4")) then
      held = true
    end
  end

  if held then
    emergencyQuitTimer = emergencyQuitTimer + (dt or 0.016)
    if emergencyQuitTimer >= 5.0 then
      print("[FORCE QUIT] Start + Select held for 5 seconds. Exiting forcefully.")
      pcall(function()
        if love.audio and love.audio.stop then love.audio.stop() end
        if love.window and love.window.close then love.window.close() end
      end)
      local exitFn = os["exit"]
      exitFn(0)
    end
  else
    emergencyQuitTimer = 0
  end
end

-- Emergency crash handler installation
do
  local defaultErrorHandler = love.errorhandler or love.errhand
  function love.errorhandler(msg)
    local traceback = debug.traceback()
    if os.getenv("POKEPORT_DRIVER") then
      io.stdout:write("LUA ERROR: " .. tostring(msg) .. "\n" .. traceback .. "\n")
      io.stdout:flush()
      os.exit(3)
    end
    local ok, hint, source, report = pcall(SwitchDiagnostics.logLuaError, msg, traceback)
    local nativeMsg = tostring(msg)
    if ok then
      if source then nativeMsg = source .. "\n\n" .. nativeMsg end
      if hint then nativeMsg = nativeMsg .. "\n\n" .. hint end
    end

    local okScreen, CrashScreen = pcall(require, "src.debug.CrashScreen")
    if okScreen and report then
      local summaryOk, summary = pcall(CrashScreen.fallbackText, report)
      if summaryOk then nativeMsg = summary end
      if love.window and love.graphics and love.event then
        local function ready()
          local openOk, open = pcall(love.window.isOpen)
          local activeOk, active = pcall(love.graphics.isActive)
          return openOk and open and activeOk and active
        end
        local variant
        if ready() then variant = "emerald"
        elseif love.window.setMode then
          local modeOk, opened = pcall(love.window.setMode, 800, 600)
          if modeOk and opened and ready() then variant = "ruby" end
        end
        if variant then
          local prepared, screen = pcall(CrashScreen.new, report, variant)
          if prepared and screen then
            local fallbackLoop
            return function()
              if fallbackLoop then return fallbackLoop() end
              local drawn, result = pcall(function()
                love.event.pump()
                for e, a, b, c, d, touchMouse in love.event.poll() do
                  if e == "quit" or (e == "keypressed" and a == "escape") then return 1
                  elseif e == "gamepadpressed" and (b == "start" or b == "back") then return 1
                  elseif e == "mousepressed" and c == 1 and not d and CrashScreen.hitClose(screen, a, b) then return 1
                  elseif e == "touchpressed" and CrashScreen.hitClose(screen, b, c) then return 1
                  elseif e == "mousepressed" and c == 1 and not d then CrashScreen.pointerPressed(screen, "mouse", a, b)
                  elseif e == "mousereleased" and c == 1 and not d then CrashScreen.pointerReleased(screen, "mouse")
                  elseif e == "mousemoved" and not touchMouse then CrashScreen.pointerMoved(screen, "mouse", a, b)
                  elseif e == "touchpressed" then CrashScreen.pointerPressed(screen, a, b, c)
                  elseif e == "touchmoved" then CrashScreen.pointerMoved(screen, a, b, c)
                  elseif e == "touchreleased" then CrashScreen.pointerReleased(screen, a)
                  elseif e == "wheelmoved" then CrashScreen.scroll(screen, -b * 3 * (screen.lineHeight or 16))
                  elseif e == "keypressed" and (a == "up" or a == "down") then
                    CrashScreen.scroll(screen, (a == "down" and 1 or -1) * (screen.lineHeight or 16))
                  elseif e == "keypressed" and (a == "pageup" or a == "pagedown") then
                    CrashScreen.scroll(screen, (a == "pagedown" and 1 or -1) * ((screen.detailArea and screen.detailArea.h) or 64))
                  elseif e == "keypressed" and (a == "home" or a == "end") then CrashScreen.scrollTo(screen, a == "end")
                  elseif e == "gamepadpressed" and (b == "dpup" or b == "dpdown") then
                    CrashScreen.scroll(screen, (b == "dpdown" and 1 or -1) * 3 * (screen.lineHeight or 16))
                  elseif e == "keypressed" and a == "c" and screen.canCopy and love.keyboard.isDown("lctrl", "rctrl") then
                    local copyOk, copied = pcall(love.system.setClipboardText, report.logPath)
                    if copyOk and copied ~= false then screen.copied = true end
                  end
                end
                checkEmergencyQuit(0.016)
                CrashScreen.draw(screen)
                love.graphics.present()
                if love.timer then love.timer.sleep(0.016) end
              end)
              if drawn then return result end
              if defaultErrorHandler then
                local fallbackOk, loop = pcall(defaultErrorHandler, nativeMsg)
                if fallbackOk and type(loop) == "function" then
                  fallbackLoop = loop
                  return fallbackLoop()
                end
              end
              return 1
            end
          end
        end
      end
    end

    if defaultErrorHandler then return defaultErrorHandler(nativeMsg) end
  end
  love.errhand = love.errorhandler
end

if POKEPORT_DISPLAY_COMPANION then
  local okCompanion, DesktopCompanion = pcall(require, "src.render.DesktopCompanion")
  if okCompanion and DesktopCompanion.install then
    return DesktopCompanion.install(POKEPORT_DISPLAY_COMPANION)
  end
end

--------------------------------------------------------------------------------
-- 4. OVERLAYS, EDITORS & LAUNCHER HELPERS
--------------------------------------------------------------------------------
local editorHost, editorVersion, editorWindow
local closeEditor, closeTouchControlsEditor, closeSkinStudio, bootGame

local function addEditorRequirePath()
  local fs = love.filesystem
  if not (fs.setRequirePath and fs.getRequirePath) then
    package.path = fs.getSource() .. "/tools/save-editor/?.lua;"
                .. fs.getSource() .. "/tools/save-editor/panels/?.lua;"
                .. package.path
    return
  end
  local current = fs.getRequirePath()
  if current:find("tools/save%-editor") then return end
  fs.setRequirePath("tools/save-editor/?.lua;tools/save-editor/panels/?.lua;" .. current)
end

local function resizeForEditor()
  if not (love.window and love.window.getMode and love.window.setMode) then return end
  local osName = love.system.getOS()
  if osName ~= "OS X" and osName ~= "Windows" and osName ~= "Linux" then return end
  local w, h, flags = love.window.getMode()
  if flags.fullscreen then return end
  local dw, dh = love.window.getDesktopDimensions()
  local wantW = math.max(w, math.min(1360, math.floor((dw or w) * 0.92)))
  local wantH = math.max(h, math.min(860, math.floor((dh or h) * 0.88)))
  if wantW <= w and wantH <= h then return end
  editorWindow = { w = w, h = h }
  love.window.setMode(wantW, wantH, flags)
end

local function restoreWindow()
  if not editorWindow then return end
  local _, _, flags = love.window.getMode()
  love.window.setMode(editorWindow.w, editorWindow.h, flags)
  editorWindow = nil
end

local function openEditor(version, slotId)
  local function refuse(text)
    if not Importer then return end
    Importer.saveNotice = Importer.saveNotice or {}
    Importer.saveNotice[version] = { ok = false, text = text }
  end
  local SaveData = safeRequire("src.core.SaveData")
  local path = SaveData and SaveData.slotDiskPath and SaveData.slotDiskPath(version, slotId)
  if not path then refuse("Could not resolve that save slot on disk."); return end
  local GameVersion = safeRequire("src.core.GameVersion")
  if GameVersion then GameVersion.set(version) end
  local CacheFs = safeRequire("src.import.CacheFs")
  if CacheFs then CacheFs.mountVersion(version) end

  editorVersion = version
  editorHost = Importer
  if Importer and Importer.prepareOverlayHandoff then Importer:prepareOverlayHandoff() end
  Importer = nil
  editorMode = true
  resizeForEditor()
  addEditorRequirePath()

  local okReq, appOrErr = pcall(require, "App")
  if not okReq then
    editorMode = false
    SessionLifecycle.endEditorSession({ version = version, app = nil })
    restoreWindow()
    Importer = editorHost
    editorHost, editorVersion = nil, nil
    if Importer and Importer.resumeAfterOverlay then Importer:resumeAfterOverlay() end
    refuse("Could not open the save editor (" .. tostring(appOrErr) .. ").")
    return
  end
  EditorApp = appOrErr
  local okLoad, loadErr = pcall(EditorApp.load, path, {
    version = version, slotId = slotId, embedded = true,
    onClose = function() closeEditor() end,
  })
  if not okLoad then
    editorMode = false
    if EditorApp.unload then pcall(EditorApp.unload) end
    EditorApp = nil
    SessionLifecycle.endEditorSession({ version = version, app = nil })
    restoreWindow()
    Importer = editorHost
    editorHost, editorVersion = nil, nil
    if Importer and Importer.resumeAfterOverlay then Importer:resumeAfterOverlay() end
    refuse("Could not open the save editor (" .. tostring(loadErr) .. ").")
  end
end

function closeEditor()
  local version = editorVersion
  local app = EditorApp
  editorMode = false
  EditorApp = nil
  SessionLifecycle.endEditorSession({ version = version, app = app })
  editorVersion = nil
  restoreWindow()
  Importer = editorHost
  editorHost = nil
  if Importer and Importer.resumeAfterOverlay then Importer:resumeAfterOverlay() end
  if Importer and version and Importer.savesChanged then Importer:savesChanged(version) end
end

local touchEditorHost
local function openTouchControlsEditor(version)
  touchEditorHost = Importer
  if Importer and Importer.prepareOverlayHandoff then Importer:prepareOverlayHandoff() end
  Importer = nil
  TouchEditor = safeRequire("src.ui.TouchControlsEditor")
  if TouchEditor then
    TouchEditor.load({ version = version, onClose = function() closeTouchControlsEditor() end })
  end
end

function closeTouchControlsEditor()
  if TouchEditor and TouchEditor.unload then TouchEditor.unload() end
  TouchEditor = nil
  Importer = touchEditorHost
  touchEditorHost = nil
  if Importer and Importer.resumeAfterOverlay then Importer:resumeAfterOverlay() end
end

local studioHost
local function openSkinStudio(version, skinId)
  local SkinStudio = safeRequire("src.ui.SkinStudio")
  if not (SkinStudio and SkinStudio.available_desktop and SkinStudio.available_desktop()) then return end
  studioHost = Importer
  if Importer and Importer.prepareOverlayHandoff then Importer:prepareOverlayHandoff() end
  Importer = nil
  Studio = SkinStudio
  Studio.load({
    version = version,
    skinId = skinId,
    onClose = function() closeSkinStudio() end,
    onPlay = function(v)
      closeSkinStudio()
      Importer = nil
      bootGame(v or version)
    end,
  })
end

function closeSkinStudio()
  if Studio and Studio.unload then Studio.unload() end
  Studio = nil
  Importer = studioHost
  studioHost = nil
  if Importer and Importer.resumeAfterOverlay then Importer:resumeAfterOverlay() end
end

local function makeLauncher(launcherOpts)
  local LauncherWindow = safeRequire("src.import.LauncherWindow")
  if LauncherWindow then LauncherWindow.activate() end
  local RomImporter = safeRequire("src.import.RomImporter")
  if not RomImporter then return nil end

  local forceImport = os.getenv("POKEPORT_FORCE_IMPORT") == "1"
  local SkinStudio = safeRequire("src.ui.SkinStudio")

  return RomImporter.new(function(version, cartId, opts)
    if LauncherWindow then
      LauncherWindow.observe(0)
      LauncherWindow.flush()
    end
    Importer = nil
    local onBoot = launcherOpts and launcherOpts.onBoot
    if onBoot and onBoot(version, cartId, opts) then return end
    bootGame(version, cartId, opts)
  end, {
    launcher = true,
    forceImport = forceImport,
    initialTab = launcherOpts and launcherOpts.initialTab or nil,
    invite = launcherOpts and launcherOpts.invite or nil,
    onEditSave = openEditor,
    onEditTouchControls = openTouchControlsEditor,
    onOpenSkinStudio = (SkinStudio and SkinStudio.available_desktop()) and openSkinStudio or nil,
  })
end

local function returnToLauncher(opts)
  if not Game then return end
  local RequireGuard = safeRequire("src.core.RequireGuard")
  if RequireGuard and RequireGuard.repair() then print("boot: restored love.filesystem searcher") end

  local GameVersion = safeRequire("src.core.GameVersion")
  local currentVersion = GameVersion and GameVersion.get()
  SessionLifecycle.endGameSession(Game)
  Game = nil
  pcall(function() require("src.online.Trade").hostIsLive = nil end)

  local syncEngine = package.loaded["src.sync.SyncEngine"]
  if type(syncEngine) == "table" and type(syncEngine._shared) == "table" then
    pcall(syncEngine._shared.protectPlaythrough, syncEngine._shared, nil, nil)
  end
  autopilot, driverCo = nil, nil

  local SaveData = safeRequire("src.core.SaveData")
  local cartId = SaveData and SaveData.getCart()
  if SaveData then
    SaveData.setCart(nil)
    if currentVersion then SaveData.refreshSlotResolution(currentVersion) end
    if cartId then SaveData.refreshSlotResolution("cart_" .. cartId) end
  end

  local GameSpeed = safeRequire("src.core.GameSpeed")
  if GameSpeed then GameSpeed.setAllowed(nil) end

  SessionLifecycle.endMountedSession(currentVersion)
  applySavedOrientation()

  local LauncherMods = safeRequire("src.mods.LauncherMods")
  if LauncherMods and LauncherMods.translationStrings then
    local preload = LauncherMods.translationStrings()
    local Strings = safeRequire("src.core.Strings")
    if preload and Strings then Strings.load({ strings = preload }) end
  end

  if love.window and love.window.setTitle then
    local Version = safeRequire("src.core.Version")
    if Version then love.window.setTitle(Version.title("Gen 3 Recompilation Project")) end
  end

  Importer = makeLauncher({ initialTab = opts and opts.tab or nil, invite = opts and opts.invite or nil })
  if Importer and Importer.ignoreReturningPointer then Importer:ignoreReturningPointer() end
end

function bootGame(version, cartId, opts)
  opts = opts or {}
  local RequireGuard = safeRequire("src.core.RequireGuard")
  if RequireGuard and RequireGuard.repair() then print("boot: restored love.filesystem searcher") end
  pcall(function() require("src.online.Trade").hostIsLive = function() return true end end)

  local GameVersion = safeRequire("src.core.GameVersion")
  if GameVersion then
    GameVersion.set(version or os.getenv("POKEPORT_VERSION") or "emerald")
    local CacheFs = safeRequire("src.import.CacheFs")
    if CacheFs then
      CacheFs.prefix = GameVersion.cachePrefix()
      CacheFs.mountVersion(GameVersion.get())
    end
  end

  local cartHash, cartSpeeds, cartOptions
  if cartId then
    local CartStore = safeRequire("src.carts.CartStore")
    local ok, cart, hash = pcall(function() return CartStore.get(cartId) end)
    if ok and cart then cartHash, cartSpeeds, cartOptions = hash, cart.speeds, cart.options
    else cartId = nil end
  end

  local SaveData = safeRequire("src.core.SaveData")
  if SaveData then
    SaveData.setCart(cartId, cartHash)
    if cartOptions then SaveData.seedCartOptions(cartOptions) end
    if cartId then SaveData.adoptCartSeal(cartId) end
  end

  local GameSpeed = safeRequire("src.core.GameSpeed")
  if GameSpeed then GameSpeed.setAllowed(cartSpeeds) end

  if GameVersion then
    pcall(function() SwitchDiagnostics.probeAssets(GameVersion.get()) end)
    if love.window and love.window.setTitle then
      local Version = safeRequire("src.core.Version")
      if Version then love.window.setTitle(Version.title(GameVersion.info().displayName .. " (Gen 3 Recompilation Project)")) end
    end
  end

  local arena = opts.arena
  local loadOpts = { arena = arena, cartId = cartId, onExit = opts.onExit }

  if GameVersion and GameVersion.generation() == 3 then
    package.loaded["src.core.Game3"] = nil
    local Game3 = safeRequire("src.core.Game3")
    if Game3 then
      Game = Game3.new()
      if arena then Game.returnToLauncher = function(o) pendingLauncherReturn = o or {} end end
      Game:load(loadOpts)
      if os.getenv("POKEPORT_AUTOPILOT") then autopilot = safeRequire("tests.autopilot") end
    end
  else
    package.loaded["src.core.Game"] = nil
    Game = safeRequire("src.core.Game")
    if Game then
      if arena then Game.returnToLauncher = function(o) pendingLauncherReturn = o or {} end end
      Game:load(loadOpts)
    end
  end

  local driverPath = os.getenv("POKEPORT_DRIVER")
  if driverPath then
    local fn = assert(loadfile(driverPath))()
    driverCo = coroutine.create(fn)
  end
  if Game then
    Game.speedOverride = (autopilot or driverCo) and 1 or speedOverride
  end
end

local function showLauncher(version)
  LaunchOptions.pendingTab = version
  if not Importer then Importer = makeLauncher({ initialTab = version }) end
end

local function wantsModUpdate(request)
  if type(request) ~= "table" then return false end
  if type(request.tasks) == "table" and request.tasks.mods ~= nil then
    return request.tasks.mods == true
  end
  return request.updateMods == true
end

local function autoUpdateMods(request, tab)
  if not wantsModUpdate(request) then return end
  if Importer and Importer.autoUpdateAll then Importer:autoUpdateAll(function() end, { tab = tab }) end
end

local deferredLaunchRequest
local function launcherBusy()
  return launcherSplash ~= nil or (Importer ~= nil and (Importer._updateAll ~= nil
    or Importer._modInstall ~= nil or Importer._cartInstall ~= nil or Importer._autoUpdateAll ~= nil))
end

local function startLaunchRequest(request)
  if type(request) ~= "table" then return false end
  if launcherBusy() then
    deferredLaunchRequest = request
    return true
  end

  local version = request.game
  if request.launcher or not version then
    if Game then returnToLauncher({ tab = version }) else showLauncher(version) end
    autoUpdateMods(request, not version and "mods" or nil)
    return true
  end

  local RomImporter = safeRequire("src.import.RomImporter")
  if Game then returnToLauncher() end
  Importer = nil
  if Prelaunch then return true end

  local cartId
  if request.cartSpecified then
    local CartStore = safeRequire("src.carts.CartStore")
    local ok, cart = pcall(function() return CartStore.get(request.cart) end)
    if not ok or type(cart) ~= "table" or cart.base ~= version then
      showLauncher(version)
      autoUpdateMods(request)
      return true
    end
    cartId = request.cart
  end

  if RomImporter and not RomImporter.isReady(version) then
    showLauncher(version)
    autoUpdateMods(request)
    return true
  end

  local function bootShortcut()
    if request.slot then LaunchOptions.selectSlot(version, request.slot) end
    launchedIntoGame = true
    bootGame(version, cartId)
  end

  local function bootAfterMods()
    if not wantsModUpdate(request) then return bootShortcut() end
    Importer = makeLauncher({ initialTab = "mods", onBoot = function(v, c, opts)
      if v ~= version or c ~= cartId or opts ~= nil then return false end
      bootShortcut()
      return true
    end })
    if Importer then
      Importer:autoUpdateAll(function(result)
        if not (result.ok or result.cancelled or result.skipped) then return end
        local LauncherWindow = safeRequire("src.import.LauncherWindow")
        if LauncherWindow then
          LauncherWindow.observe(0)
          LauncherWindow.flush()
        end
        Importer = nil
        bootShortcut()
      end)
    end
  end

  local PrelaunchMod = safeRequire("src.core.Prelaunch")
  if PrelaunchMod then
    Prelaunch = PrelaunchMod.new({
      version = version,
      tasks = request.tasks or {},
      done = function(outcome)
        if outcome == "restart" then return end
        Prelaunch = nil
        if outcome == "launcher" then showLauncher(version); return end
        bootAfterMods()
      end,
    })
  end
  if not Prelaunch then bootAfterMods() end
  return true
end

--------------------------------------------------------------------------------
-- 5. LÖVE2D LIFECYCLE CALLBACKS
--------------------------------------------------------------------------------
function love.load(args)
  if os.getenv("POKEPORT_BACKGROUND") == "1" and love.audio then
    love.audio.setVolume(0)
    love.audio.setVolume = function() end
  end

  local HostShell = safeRequire("src.core.HostShell")
  if HostShell then HostShell.hideHostConsole() end

  local RequireGuard = safeRequire("src.core.RequireGuard")
  if RequireGuard then RequireGuard.capture() end

  pcall(function() require("src.net.Gen1Tls").install() end)
  local Platform = safeRequire("src.core.Platform")
  if Platform and Platform.isNX and Platform.isNX() then
    pcall(function() require("src.core.NxAssetOverlay").install() end)
  end

  local Boot = safeRequire("src.update.Boot")
  if Boot and Boot.run and Boot.run(args) then return end

  local savePath
  for i, a in ipairs(args or {}) do
    if a == "--editor" then editorMode = true
    elseif a == "--developer" then _G.POKEPORT_DEV_MODE = true
    elseif a == "--save" and args[i + 1] and args[i + 1] ~= "" then savePath = args[i + 1]
    elseif a == "--speed" and tonumber(args[i + 1]) then speedOverride = tonumber(args[i + 1]) end
  end

  -- Window & Display Init
  love.window.setMode(960, 640, { resizable = true, vsync = true, minwidth = 240, minheight = 160 })
  love.window.setTitle("Gen 3 Engine")
  love.graphics.setDefaultFilter("nearest", "nearest")

  ViewportManager.init(240, 160)
  InputAdapter.init()

  if BattleRenderer then battleRenderer = BattleRenderer.new() end

  -- Init Engine Map Renderer
  map = MapRenderer.new(16)
  if map and map.loadMapData then
    map:loadMapData({
      width = 10, height = 10,
      layers = {
        bg = { 1,1,1,1,1, 1,1,1,1,1, 1,2,2,2,1, 1,2,2,2,1, 1,2,2,2,1, 1,2,2,2,1 },
        fg = { 0,0,0,0,0, 0,0,0,0,0 },
        collision = { 0,0,0,0,0, 0,0,0,0,0 }
      }
    })
  end

  NxDisplay.sync()
  applySavedOrientation()

  if editorMode then
    local version = os.getenv("POKEPORT_VERSION") or "emerald"
    local GameVersion = safeRequire("src.core.GameVersion")
    if GameVersion then GameVersion.set(version) end
    local CacheFs = safeRequire("src.import.CacheFs")
    if CacheFs then CacheFs.mountVersion(version) end
    addEditorRequirePath()
    EditorApp = safeRequire("App")
    if EditorApp and EditorApp.load then EditorApp.load(savePath, { version = version }) end
    return
  end

  local RomImporter = safeRequire("src.import.RomImporter")
  local resolvedLaunch = LaunchOptions.resolveRequest(arg, args) or {}
  local forceImport = os.getenv("POKEPORT_FORCE_IMPORT") == "1"
  local importPath = os.getenv("POKEPORT_IMPORT_ROM")
  local scriptedVersion = os.getenv("POKEPORT_VERSION") or resolvedLaunch.game or "emerald"
  local ready = RomImporter and RomImporter.isReady(scriptedVersion)
  local scripted = os.getenv("POKEPORT_AUTOPILOT") or os.getenv("POKEPORT_DRIVER")
    or os.getenv("POKEPORT_IMPORT_ONLY") == "1" or importPath ~= nil

  local scriptedOpts = nil
  local specPath = os.getenv("POKEPORT_ARENA_SPEC")
  if specPath and os.getenv("POKEPORT_DRIVER") then
    local chunk, chunkErr = loadfile(specPath)
    if not chunk then error("POKEPORT_ARENA_SPEC: " .. tostring(chunkErr)) end
    local spec = chunk()
    if type(spec) ~= "table" then error("POKEPORT_ARENA_SPEC must return an ArenaSpec table") end
    scriptedOpts = { arena = spec }
  end

  if scripted then
    if forceImport or not ready then
      if RomImporter then
        Importer = RomImporter.new(function(version)
          if os.getenv("POKEPORT_IMPORT_ONLY") == "1" then love.event.quit(); return end
          Importer = nil
          bootGame(version or scriptedVersion, nil, scriptedOpts)
        end)
        if importPath and Importer and Importer.startPath then Importer:startPath(importPath) end
      end
      return
    end
    bootGame(scriptedVersion, nil, scriptedOpts)
    return
  end

  local LauncherMods = safeRequire("src.mods.LauncherMods")
  if LauncherMods and LauncherMods.translationStrings then
    local preload = LauncherMods.translationStrings()
    local Strings = safeRequire("src.core.Strings")
    if preload and Strings then Strings.load({ strings = preload }) end
  end

  local relaunched = love.filesystem.getInfo(RELAUNCH_MARKER) ~= nil
  if relaunched then
    launchOptionsSuppressed = true
    pcall(love.filesystem.remove, RELAUNCH_MARKER)
  end

  if not relaunched and resolvedLaunch.game and not resolvedLaunch.launcher and startLaunchRequest(resolvedLaunch) then
    return
  end
  if not relaunched and resolvedLaunch.launcher and resolvedLaunch.game then
    LaunchOptions.pendingTab = resolvedLaunch.game
  end

  Importer = makeLauncher()
  if not relaunched then
    local LauncherSplash = safeRequire("src.import.LauncherSplash")
    if LauncherSplash then launcherSplash = LauncherSplash.new() end
    autoUpdateMods(resolvedLaunch, not resolvedLaunch.game and "mods" or nil)
  end

  -- Show default game menu if launcher failed to build or is idle
  if not Importer and not Game then
    showGameSelector()
  end
end

function love.resize(w, h)
  ViewportManager.updateScale()
  applySavedOrientation()
end

function love.update(dt)
  checkEmergencyQuit(dt)
  HostDisplay.update(dt)
  SwitchDiagnostics.maybeFlush(false)
  NxDisplay.sync()

  local safeDt = math.min(dt, 1 / 30)

  if launcherSplash then
    if launcherSplash:update(dt) then
      launcherSplash:release()
      launcherSplash = nil
      if Importer and Importer.resumeAfterOverlay then Importer:resumeAfterOverlay() end
    end
    return
  end
  if editorMode and EditorApp then return EditorApp.update(dt) end
  if TouchEditor then return TouchEditor.update(dt) end
  if Studio then return Studio.update(dt) end

  local launchURI = LaunchOptions.pollURI()
  if launchURI then love.handlers.intent_uri(launchURI) end
  if deferredLaunchRequest and not launcherBusy() then
    local request = deferredLaunchRequest
    deferredLaunchRequest = nil
    startLaunchRequest(request)
  end
  if Prelaunch then return Prelaunch:update(dt) end

  local connect = package.loaded["src.online.Connect"]
  if connect then pcall(connect.update, dt) end
  local client = onlineClientModule()
  if client then pcall(client.update, dt) end

  if pendingLauncherReturn then
    local opts = pendingLauncherReturn
    pendingLauncherReturn = nil
    returnToLauncher(opts)
    return
  end
  if Importer then
    local LauncherWindow = safeRequire("src.import.LauncherWindow")
    if LauncherWindow then LauncherWindow.observe(dt) end
    return Importer:update(dt)
  end

  if battleRenderer then battleRenderer:update(safeDt, nil, nil) end

  if Game then
    local iterations = scriptedIterations()
    if autopilot then
      for _ = 1, iterations do autopilot.update(); Game:update(1 / 60) end
      return
    end
    if driverCo then
      local i = 0
      while i < iterations do
        i = i + 1
        local ok, err = coroutine.resume(driverCo, Game)
        if not ok then print("driver error: " .. tostring(err)); love.event.quit(1); return end
        if coroutine.status(driverCo) == "dead" then love.event.quit(); return end
        Game:update(1 / 60)
        iterations = math.min(iterations, scriptedIterations())
      end
      return
    end
    PlatformHooks.update(Game, dt)
  end
end

function love.draw()
  if gameMenuState.active then
    drawGameSelector()
    return
  end

  if editorMode and EditorApp then
    GameViewport.reset()
    HostDisplay.beginFrame("editor", EditorApp)
    local result = EditorApp.draw()
    HostDisplay.endFrame("editor", EditorApp)
    return result
  end
  if TouchEditor then
    GameViewport.reset()
    HostDisplay.beginFrame("touch_editor", TouchEditor)
    local result = TouchEditor.draw()
    HostDisplay.endFrame("touch_editor", TouchEditor)
    return result
  end
  if Studio then
    HostDisplay.beginFrame("skin_studio", Studio)
    local result = Studio.draw()
    HostDisplay.endFrame("skin_studio", Studio)
    return result
  end
  if Prelaunch then
    GameViewport.reset()
    return Prelaunch:draw()
  end
  if Importer then
    GameViewport.reset()
    HostDisplay.beginFrame("launcher", Importer)
    local result = Importer:draw()
    if launcherSplash then launcherSplash:draw() end
    HostDisplay.endFrame("launcher", Importer)
    return result
  end

  -- Render active game inside Virtual Scaled Canvas
  ViewportManager.attach()
    if map then
      map:drawLayer("bg")
      map:drawLayer("fg")
    end

    if Game then
      HostDisplay.beginFrame("game", Game)
      Game:draw()
      HostDisplay.endFrame("game", Game)
    elseif battleRenderer then
      battleRenderer:draw(nil, nil, "Battle Engine Ready...")
    end

    if love.system and (love.system.getOS() == "Android" or love.system.getOS() == "iOS") then
      InputAdapter.drawTouchControls()
    end
  ViewportManager.detach()

  if Game and Game.capturePath then
    local path = Game.capturePath
    Game.capturePath = nil
    love.graphics.captureScreenshot(function(imagedata)
      local fd = imagedata:encode("png")
      local f = io.open(path, "wb")
      if f then f:write(fd:getString()); f:close() end
    end)
  end
end

--------------------------------------------------------------------------------
-- 6. INPUT CONTROLLER & KEYBOARD BINDINGS
--------------------------------------------------------------------------------
function love.keypressed(key, scancode, isrepeat)
  -- Hotkey to open ROM Importer overlay on demand (F8 or Ctrl+I)
  if key == "f8" or (key == "i" and love.keyboard.isDown("lctrl", "rctrl")) then
    local RomImporter = safeRequire("src.import.RomImporter")
    if RomImporter then
      Importer = RomImporter.new(function(version, cartId, opts)
        Importer = nil
        if version then bootGame(version, cartId, opts) end
      end, { launcher = false, forceImport = true })
    end
    return
  end

  -- Main Cartridge Selector Navigation Controls
  if gameMenuState.active then
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local isPortrait = h > w

    if key == "up" or (not isPortrait and key == "left") then
      gameMenuState.selectedIndex = math.max(1, gameMenuState.selectedIndex - 1)
      return
    elseif key == "down" or (not isPortrait and key == "right") then
      gameMenuState.selectedIndex = math.min(#gameMenuState.games, gameMenuState.selectedIndex + 1)
      return
    elseif key == "return" or key == "z" or key == "space" then
      local selected = gameMenuState.games[gameMenuState.selectedIndex]
      gameMenuState.active = false
      bootGame(selected.id)
      return
    end
  end

  -- Return to Game Selector from anywhere via Escape
  if key == "escape" and not gameMenuState.active then
    showGameSelector()
    return
  end

  if key == "f11" then
    local isFull = love.window.getFullscreen()
    love.window.setFullscreen(not isFull, "desktop")
    ViewportManager.updateScale()
  elseif key == "f5" then
    local saveData = SaveSystem.buildSaveData(player, party, {}, { badge1 = true })
    SaveSystem.save("save1.dat", saveData)
  elseif key == "f9" then
    local data = SaveSystem.load("save1.dat")
    if data and data.player then player.x = data.player.x; player.y = data.player.y end
  end

  InputAdapter.updateKey(key, true)

  if launcherSplash then return end
  if editorMode and EditorApp then return EditorApp.keypressed(key) end
  if TouchEditor then return TouchEditor.keypressed(key) end
  if Studio then return Studio.keypressed(key) end
  if Prelaunch then return Prelaunch:cancel() end
  if Importer then return Importer:keypressed(key) end
  if Game then Game:keypressed(key) end
end

function love.keyreleased(key)
  InputAdapter.updateKey(key, false)
  if launcherSplash or editorMode or TouchEditor or Studio or Importer then return end
  if Game then Game:keyreleased(key) end
end

function love.mousepressed(x, y, button, istouch)
  if button == 1 then InputAdapter.handleTouch(x, y, true, ViewportManager) end

  -- Cartridge Selection Touch Controls
  if gameMenuState.active and button == 1 then
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local isPortrait = h > w
    local titleY = isPortrait and 45 or 32

    if isPortrait then
      local cartW = math.min(w * 0.82, 320)
      local cartH = 64
      local startY = titleY + 70
      local spacing = 12

      for i = 1, #gameMenuState.games do
        local cartX = (w - cartW) / 2
        local cartY = startY + (i - 1) * (cartH + spacing)

        if x >= cartX and x <= cartX + cartW and y >= cartY and y <= cartY + cartH then
          if gameMenuState.selectedIndex == i then
            local selected = gameMenuState.games[i]
            gameMenuState.active = false
            bootGame(selected.id)
          else
            gameMenuState.selectedIndex = i
          end
          return
        end
      end
    else
      local cartW = 160
      local cartH = 110
      local totalW = (#gameMenuState.games * cartW) + ((#gameMenuState.games - 1) * 16)
      local startX = (w - totalW) / 2
      local cartY = titleY + 65

      for i = 1, #gameMenuState.games do
        local cartX = startX + (i - 1) * (cartW + 16)

        if x >= cartX and x <= cartX + cartW and y >= cartY and y <= cartY + cartH then
          if gameMenuState.selectedIndex == i then
            local selected = gameMenuState.games[i]
            gameMenuState.active = false
            bootGame(selected.id)
          else
            gameMenuState.selectedIndex = i
          end
          return
        end
      end
    end
  end

  if launcherSplash then return end
  if TouchEditor then return TouchEditor.mousepressed(x, y, button) end
  if Studio then return Studio.mousepressed(x, y, button) end
  if Prelaunch then return Prelaunch:cancel() end
  if Importer then return Importer:mousepressed(x, y, button) end
  if editorMode and EditorApp and EditorApp.mousepressed then return EditorApp.mousepressed(x, y, button) end
  if mouseTouch and Game and button == 1 then Game:touchpressed("mouse", x, y) end
  if Game then Game:mousepressed(x, y, button, istouch) end
end

function love.mousereleased(x, y, button, istouch)
  if button == 1 then InputAdapter.handleTouch(x, y, false, ViewportManager) end
  if launcherSplash then return end
  if TouchEditor then return TouchEditor.mousereleased(x, y, button) end
  if Studio then return Studio.mousereleased(x, y, button) end
  if Importer then return end
  if editorMode and EditorApp and EditorApp.mousereleased then return EditorApp.mousereleased(x, y, button) end
  if mouseTouch and Game and button == 1 then Game:touchreleased("mouse", x, y) end
  if Game then Game:mousereleased(x, y, button, istouch) end
end

function love.mousemoved(x, y, dx, dy, istouch)
  if launcherSplash then return end
  if TouchEditor then return TouchEditor.mousemoved(x, y) end
  if Studio then return Studio.mousemoved(x, y) end
  if editorMode or Importer then return end
  if mouseTouch and Game and love.mouse.isDown(1) then Game:touchmoved("mouse", x, y) end
  if Game then Game:mousemoved(x, y, dx, dy, istouch) end
end

function love.gamepadpressed(joystick, button)
  if launcherSplash then return end
  SwitchDiagnostics.onJoystickEvent("gamepadpressed", joystick, button)
  if PadHints.windowMinimized() then return end
  if editorMode then if EditorApp and EditorApp.gamepadpressed then return EditorApp.gamepadpressed(joystick, button) end; return end
  if TouchEditor then if TouchEditor.gamepadpressed then return TouchEditor.gamepadpressed(joystick, button) end; return end
  if Studio then return Studio.gamepadpressed(joystick, button) end
  if Prelaunch then return Prelaunch:cancel() end
  if Importer then return Importer:gamepadpressed(joystick, button) end
  if Game then Game:gamepadpressed(joystick, button) end
end

function love.gamepadreleased(joystick, button)
  if launcherSplash then return end
  SwitchDiagnostics.onJoystickEvent("gamepadreleased", joystick, button)
  if editorMode then if EditorApp and EditorApp.gamepadreleased then return EditorApp.gamepadreleased(joystick, button) end; return end
  if TouchEditor then if TouchEditor.gamepadreleased then return TouchEditor.gamepadreleased(joystick, button) end; return end
  if Studio then return Studio.gamepadreleased(joystick, button) end
  if Importer then return Importer:gamepadreleased(joystick, button) end
  if Game then Game:gamepadreleased(joystick, button) end
end

function love.gamepadaxis(joystick, axis, value)
  if launcherSplash then return end
  SwitchDiagnostics.onJoystickEvent("gamepadaxis", joystick, axis, { value = value })
  if PadHints.windowMinimized() then value = 0 end
  if editorMode then if EditorApp and EditorApp.gamepadaxis then return EditorApp.gamepadaxis(joystick, axis, value) end; return end
  if TouchEditor then if TouchEditor.gamepadaxis then return TouchEditor.gamepadaxis(joystick, axis, value) end; return end
  if Studio then return Studio.gamepadaxis(joystick, axis, value) end
  if Importer then return Importer:gamepadaxis(joystick, axis, value) end
  if Game then Game:gamepadaxis(joystick, axis, value) end
end

function love.joystickpressed(j, b) if Game then Game:joystickpressed(j, b) end end
function love.joystickreleased(j, b) if Game then Game:joystickreleased(j, b) end end
function love.joystickaxis(j, a, v) if Game then Game:joystickaxis(j, a, v) end end
function love.joystickhat(j, h, d) if Game then Game:joystickhat(j, h, d) end end
function love.joystickadded(j) if Game then Game:joystickadded(j) end end
function love.joystickremoved(j) if Game then Game:joystickremoved(j) end end

function love.focus(f)
  SwitchDiagnostics.onFocus(f)
  if editorMode or TouchEditor then return end
  if Studio then if Studio.focus then Studio.focus(f) end; return end
  if Importer then
    local InputMod = safeRequire("src.core.Input")
    if InputMod then InputMod:reset() end
    if Importer.focus then Importer:focus(f) end
    return
  end
  if Game then Game:focus(f) end
end

function love.visible(v)
  if editorMode or TouchEditor then return end
  if Studio then if Studio.visible then Studio.visible(v) end; return end
  if Importer then
    local InputMod = safeRequire("src.core.Input")
    if InputMod then InputMod:reset() end
    return
  end
  if Game then Game:visible(v) end
end

function love.lowmemory()
  if editorMode or TouchEditor or Studio or Importer then return end
  if Game and Game.onResume then Game:onResume() end
end

love.handlers = love.handlers or {}

function love.handlers.audiosuspend()
  local ChipAudio = package.loaded["src.core.ChipAudio"]
  if ChipAudio then pcall(ChipAudio.setSuspended, true) end
  local Sound = package.loaded["src.core.Sound"]
  if Sound then pcall(Sound.onDeviceReset) end
  local Game3Audio = package.loaded["src.core.game3.audio"]
  if Game3Audio then pcall(Game3Audio.setSuspended, true) end
end

function love.handlers.audioreset()
  local ChipAudio = package.loaded["src.core.ChipAudio"]
  if ChipAudio then pcall(ChipAudio.setSuspended, false); pcall(ChipAudio.rebuildPlayback) end
  local Music = package.loaded["src.core.Music"]
  if Music then pcall(Music.onDeviceReset) end
  local Sound = package.loaded["src.core.Sound"]
  if Sound then pcall(Sound.onDeviceReset) end
  local Game3Audio = package.loaded["src.core.game3.audio"]
  if Game3Audio then pcall(Game3Audio.setSuspended, false); pcall(Game3Audio.rebuildPlayback) end
end

function love.handlers.intent_game(version)
  local request = LaunchOptions.fromGame(version)
  if request then startLaunchRequest(request) end
end

function love.handlers.intent_uri(uri)
  local request = LaunchOptions.parseURI(uri)
  if request then startLaunchRequest(request)
  elseif LaunchOptions.isLaunchURI(uri) then startLaunchRequest({}) end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
  if launcherSplash then return end
  if TouchEditor then return TouchEditor.touchpressed(id, x, y) end
  if Studio then return Studio.touchpressed(id, x, y) end
  if Prelaunch then return Prelaunch:cancel() end
  if Importer then return Importer:touchpressed(id, x, y, dx, dy, pressure) end
  if Game then Game:touchpressed(id, x, y, dx, dy, pressure) end
end

function love.touchmoved(id, x, y, dx, dy, pressure)
  if launcherSplash then return end
  if TouchEditor then return TouchEditor.touchmoved(id, x, y) end
  if Studio then return Studio.touchmoved(id, x, y) end
  if Importer then return Importer:touchmoved(id, x, y, dx, dy, pressure) end
  if Game then Game:touchmoved(id, x, y, dx, dy, pressure) end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
  if launcherSplash then return end
  if TouchEditor then return TouchEditor.touchreleased(id, x, y) end
  if Studio then return Studio.touchreleased(id, x, y) end
  if Importer then return Importer:touchreleased(id, x, y, dx, dy, pressure) end
  if Game then Game:touchreleased(id, x, y, dx, dy, pressure) end
end

function love.wheelmoved(x, y)
  if launcherSplash then return end
  if editorMode and EditorApp and EditorApp.wheelmoved then return EditorApp.wheelmoved(x, y) end
  if Studio then return Studio.wheelmoved(x, y) end
  if Game then Game:wheelmoved(x, y) end
end

function love.textinput(text)
  if launcherSplash then return end
  if Studio then return Studio.textinput(text) end
  if Importer then return Importer:textinput(text) end
  if editorMode and EditorApp and EditorApp.textinput then return EditorApp.textinput(text) end
end

function love.quit()
  if launcherSplash then launcherSplash:release(); launcherSplash = nil end
  if Importer then
    local LauncherWindow = safeRequire("src.import.LauncherWindow")
    if LauncherWindow then
      LauncherWindow.observe(0)
      LauncherWindow.flush()
    end
  end
  if editorMode and EditorApp and EditorApp.quit then
    if EditorApp.quit() then return true end
  end
  local scripted = os.getenv("POKEPORT_AUTOPILOT") or os.getenv("POKEPORT_DRIVER")
    or os.getenv("POKEPORT_IMPORT_ONLY") == "1" or os.getenv("POKEPORT_IMPORT_ROM")
  local osName = love.system and love.system.getOS and love.system.getOS()
  local inProcessReturn = (osName == "Android" or osName == "iOS")
  local wouldReturnToLauncher = PlatformHooks.quitToLauncher(function()
    return Game and not Importer and not quitToLauncher and not scripted and (inProcessReturn or not launchedIntoGame)
  end)
  if wouldReturnToLauncher then
    if inProcessReturn then returnToLauncher(); return true end
    quitToLauncher = true
    pcall(love.filesystem.write, RELAUNCH_MARKER, "1")
    local HostShell = safeRequire("src.core.HostShell")
    if HostShell then HostShell.restart() end
    return true
  end
  pcall(function() require("src.core.DiscordPresence").shutdown() end)
  SessionLifecycle.endProcess()
end

function love.filedropped(file)
  if launcherSplash then return end
  local filename = file and file.getFilename and file:getFilename()

  if filename then
    local ext = filename:match("%.([^%.]+)$"):lower()
    if ext == "gba" or ext == "gbc" or ext == "gb" or ext == "zip" or ext == "ips" or ext == "bps" then
      processAndImportRom(filename)
      return
    end
  end

  if LaunchOptions.isLaunchURI(filename) then
    local request = LaunchOptions.parseURI(filename)
    if launchOptionsSuppressed then return end
    startLaunchRequest(request or {})
    return
  end
  if editorMode and EditorApp and EditorApp.filedropped then return EditorApp.filedropped(file) end
  if Studio then return Studio.filedropped(file) end
  if Importer then Importer:filedropped(file) end
end

--------------------------------------------------------------------------------
-- 7. CUSTOM ENGINE MAIN LOOP (love.run)
--------------------------------------------------------------------------------
local function pacingEnabled()
  if os.getenv("POKEPORT_AUTOPILOT") or os.getenv("POKEPORT_DRIVER") or os.getenv("POKEPORT_IMPORT_ONLY") == "1" then
    return false
  end
  return true
end

local function idlePresentationCap(idleFor)
  local after = tonumber(os.getenv("POKEPORT_IDLE_AFTER"))
  local fps = tonumber(os.getenv("POKEPORT_IDLE_FPS"))
  if not after or after <= 0 or not fps or fps <= 0 then return nil end
  if idleFor < after then return nil end
  if Importer or Prelaunch or editorMode or not Game then return nil end
  return fps
end

function love.run()
  if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
  if love.timer then love.timer.step() end

  local FrameCap = safeRequire("src.core.FrameCap") or { current = 60, DISPLAY = 60, DEFAULT = 60, bootPanelSync = function() end }
  _G.POKEPORT_LOOP_PANEL_SYNC = true
  if FrameCap.bootPanelSync then FrameCap.bootPanelSync() end

  local RefreshRate = safeRequire("src.core.RefreshRate") or { sample = function() end }
  local VSync = safeRequire("src.core.VSync") or { isOn = function() return false end }
  local PresentSync = safeRequire("src.core.PresentSync") or {
    onDisplayChange = function() end,
    needsSoftwareCap = function() return false end,
    waitBeforePresent = function() end,
    notePresent = function() end,
    applyFixedStepPeriod = function() end,
    hardwarePacesCap = function() return false end
  }

  local paced = pacingEnabled()
  local nextFrame = love.timer and love.timer.getTime() or 0
  local dt = 0
  local idleFor = 0
  local SLEEP_FLOOR = 0.001

  local function sleepUntilFrame(deadline)
    while true do
      local remaining = deadline - love.timer.getTime()
      if remaining <= SLEEP_FLOOR then break end
      if remaining > 0.004 then
        love.timer.sleep(remaining - 0.002)
      else
        love.timer.sleep(remaining)
      end
    end
  end

  local WAKE = {
    keypressed = true, keyreleased = true, textinput = true,
    mousepressed = true, mousereleased = true, mousemoved = true,
    wheelmoved = true, touchpressed = true, touchreleased = true,
    touchmoved = true, joystickpressed = true, joystickreleased = true,
    joystickhat = true, gamepadpressed = true, gamepadreleased = true,
    joystickadded = true, joystickremoved = true, filedropped = true,
    directorydropped = true, focus = true, visible = true, resize = true,
  }

  return function()
    if love.event then
      love.event.pump()
      for name, a, b, c, d, e, f in love.event.poll() do
        if name == "quit" then
          if not love.quit or not love.quit() then
            if love.system and love.system.getOS() == "Android" then os.exit(a or 0) end
            return a or 0
          end
        end
        if WAKE[name] then idleFor = 0
        elseif name == "joystickaxis" and type(c) == "number" and math.abs(c) > 0.5 then idleFor = 0 end
        if name == "focus" and a then PresentSync.onDisplayChange()
        elseif name == "resize" then PresentSync.onDisplayChange() end
        if love.handlers[name] then love.handlers[name](a, b, c, d, e, f) end
      end
    end

    if love.timer then dt = love.timer.step() end
    idleFor = idleFor + dt
    RefreshRate.sample(dt)

    checkEmergencyQuit(dt)

    if love.update then love.update(dt) end

    local visible = not (love.window and love.window.isVisible) or love.window.isVisible()
    local focused = not (love.window and love.window.hasFocus) or love.window.hasFocus()
    local cap = FrameCap.current

    if not visible then cap = 10
    elseif Importer and (not focused or idleFor > 30) then cap = 15
    else
      local idleCap = idlePresentationCap(idleFor)
      if idleCap then cap = idleCap end
    end

    if cap == FrameCap.DISPLAY and not VSync.isOn() then cap = FrameCap.DEFAULT
    elseif cap == FrameCap.DISPLAY and PresentSync.needsSoftwareCap() then cap = FrameCap.DEFAULT end

    if visible and love.graphics and love.graphics.isActive() then
      love.graphics.origin()
      love.graphics.clear(love.graphics.getBackgroundColor())
      if love.draw then love.draw() end
      PresentSync.waitBeforePresent()
      love.graphics.present()
      PresentSync.notePresent()
    end

    PresentSync.applyFixedStepPeriod()

    if love.timer then
      if paced and cap ~= FrameCap.DISPLAY and not PresentSync.hardwarePacesCap(cap) then
        local budget = 1 / cap
        nextFrame = nextFrame + budget
        local now = love.timer.getTime()
        if now - nextFrame > budget then nextFrame = now end
        sleepUntilFrame(nextFrame)
      else
        love.timer.sleep(0.001)
      end
    end
  end
end
