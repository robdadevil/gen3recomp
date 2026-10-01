-- src/core/engine/SaveSystem.lua
local SaveSystem = {}

-- Simple Lua table-to-string serializer
local function serializeTable(val, name, depth)
  depth = depth or 0
  local tmp = string.rep("  ", depth)
  if name then tmp = tmp .. name .. " = " end

  if type(val) == "table" then
    tmp = tmp .. "{\n"
    for k, v in pairs(val) do
      local keyStr
      if type(k) == "number" then
        keyStr = "[" .. k .. "]"
      else
        keyStr = "[\"" .. tostring(k) .. "\"]"
      end
      tmp = tmp .. serializeTable(v, keyStr, depth + 1) .. ",\n"
    end
    tmp = tmp .. string.rep("  ", depth) .. "}"
  elseif type(val) == "number" or type(val) == "boolean" then
    tmp = tmp .. tostring(val)
  elseif type(val) == "string" then
    tmp = tmp .. string.format("%q", val)
  else
    tmp = tmp .. "nil"
  end

  return tmp
end

function SaveSystem.save(filename, saveStateData)
  filename = filename or "save1.dat"
  local content = "return " .. serializeTable(saveStateData)
  
  local success, message = love.filesystem.write(filename, content)
  if success then
    print("[SaveSystem] Game state saved successfully to " .. filename)
    return true
  else
    print("[SaveSystem] Failed to write save file: " .. tostring(message))
    return false
  end
end

function SaveSystem.load(filename)
  filename = filename or "save1.dat"
  
  if not love.filesystem.getInfo(filename) then
    print("[SaveSystem] Save file not found: " .. filename)
    return nil
  end

  local chunk, err = love.filesystem.load(filename)
  if not chunk then
    print("[SaveSystem] Error loading save file: " .. tostring(err))
    return nil
  end

  -- Safe execution environment
  local success, data = pcall(chunk)
  if success and type(data) == "table" then
    print("[SaveSystem] Save file loaded successfully!")
    return data
  else
    print("[SaveSystem] Failed to parse save data.")
    return nil
  end
end

function SaveSystem.buildSaveData(player, party, inventory, badges)
  return {
    version = "1.0.0",
    timestamp = os.time(),
    player = {
      name = player.name or "Trainer",
      x = player.x or 1,
      y = player.y or 1,
      facing = player.facing or "down",
      money = player.money or 3000
    },
    badges = badges or {},
    inventory = inventory or {},
    party = party or {}
  }
end

return SaveSystem
