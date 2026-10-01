-- src/core/game3/SaveWriter.lua
local PokemonUnpacker = require("src.core.game3.PokemonUnpacker")
local SaveWriter = {}

local function writeUint16LE(val)
  local b1 = val % 256
  local b2 = math.floor(val / 256) % 256
  return string.char(b1, b2)
end

local function writeUint32LE(val)
  local b1 = val % 256
  local b2 = math.floor(val / 256) % 256
  local b3 = math.floor(val / 65536) % 256
  local b4 = math.floor(val / 16777216) % 256
  return string.char(b1, b2, b3, b4)
end

function SaveWriter.calculateSectorChecksum(sectorData)
  local sum = 0
  for i = 1, 3968, 4 do
    local b1, b2, b3, b4 = string.byte(sectorData, i, i + 3)
    local word = b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
    sum = (sum + word) % 4294967296
  end
  local upper = math.floor(sum / 65536)
  local lower = sum % 65536
  return (upper + lower) % 65536
end

function SaveWriter.packSector(sectorId, saveIndex, payloadData)
  -- Pad payload to 3968 bytes
  local paddedPayload = payloadData
  if #paddedPayload < 3968 then
    paddedPayload = paddedPayload .. string.rep(string.char(0), 3968 - #paddedPayload)
  end

  -- Build footer (128 bytes of padding/metadata)
  local footer = string.rep(string.char(0), 116)
  footer = footer .. writeUint16LE(sectorId)
  
  local partialSector = paddedPayload .. footer
  local checksum = SaveWriter.calculateSectorChecksum(partialSector)
  
  footer = footer .. writeUint16LE(checksum) .. writeUint32LE(saveIndex)
  return paddedPayload .. string.rep(string.char(0), 116) .. writeUint16LE(sectorId) .. writeUint16LE(checksum) .. writeUint32LE(saveIndex)
end

return SaveWriter
