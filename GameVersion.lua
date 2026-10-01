-- src/core/GameVersion.lua
local GameVersion = {}

local VERSIONS = {
  ruby = {
    id = "ruby",
    code = "AXVE",
    displayName = "Pokémon Ruby",
    generation = 3,
    saveSize = 131072, -- 128 KB Flash
    numBoxes = 14,
    boxCapacity = 30,
    hasRTC = true,
  },
  sapphire = {
    id = "sapphire",
    code = "AXPE",
    displayName = "Pokémon Sapphire",
    generation = 3,
    saveSize = 131072,
    numBoxes = 14,
    boxCapacity = 30,
    hasRTC = true,
  },
  emerald = {
    id = "emerald",
    code = "BPEE",
    displayName = "Pokémon Emerald",
    generation = 3,
    saveSize = 131072,
    numBoxes = 14,
    boxCapacity = 30,
    hasRTC = true,
  },
  firered = {
    id = "firered",
    code = "BPRE",
    displayName = "Pokémon FireRed",
    generation = 3,
    saveSize = 131072,
    numBoxes = 14,
    boxCapacity = 30,
    hasRTC = false,
  },
  leafgreen = {
    id = "leafgreen",
    code = "BPGE",
    displayName = "Pokémon LeafGreen",
    generation = 3,
    saveSize = 131072,
    numBoxes = 14,
    boxCapacity = 30,
    hasRTC = false,
  },
}

local currentVersion = "emerald"

function GameVersion.set(versionKey)
  local key = tostring(versionKey or "emerald"):lower()
  if VERSIONS[key] then
    currentVersion = key
  else
    currentVersion = "emerald"
  end
end

function GameVersion.get()
  return currentVersion
end

function GameVersion.info()
  return VERSIONS[currentVersion]
end

function GameVersion.generation()
  return VERSIONS[currentVersion].generation
end

function GameVersion.cachePrefix()
  return "gen3_" .. currentVersion
end

return GameVersion
