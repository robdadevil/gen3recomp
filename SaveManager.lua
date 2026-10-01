-- src/core/game3/SaveManager.lua
local SaveManager = {}

local SECTOR_SIZE = 4096 -- 4KB per sector
local TOTAL_SECTORS = 32

local function readUint16LE(data, offset)
  local b1, b2 = string.byte(data, offset + 1, offset + 2)
  return b1 + (b2 * 256)
end

local function readUint32LE(data, offset)
  local b1, b2, b3, b4 = string.byte(data, offset + 1, offset + 4)
  return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
end

function SaveManager.calculateChecksum(sectorData)
  local sum = 0
  local length = 3968 -- First 3968 bytes are checksummed
  for i = 1, length, 4 do
    local word = readUint32LE(sectorData, i - 1)
    sum = (sum + word) % 4294967296
  end
  local upper = math.floor(sum / 65536)
  local lower = sum % 65536
  return (upper + lower) % 65536
end

function SaveManager.parseSaveFile(binaryData)
  if #binaryData < 131072 then
    return nil, "Invalid save size (Expected 128KB)"
  end

  local sectors = {}
  for i = 0, TOTAL_SECTORS - 1 do
    local offset = i * SECTOR_SIZE
    local chunk = string.sub(binaryData, offset + 1, offset + SECTOR_SIZE)
    
    local sectorId = readUint16LE(chunk, 4084)
    local checksum = readUint16LE(chunk, 4086)
    local saveIndex = readUint32LE(chunk, 4088)

    sectors[i] = {
      index = i,
      sectorId = sectorId,
      checksum = checksum,
      saveIndex = saveIndex,
      data = chunk,
      valid = (SaveManager.calculateChecksum(chunk) == checksum)
    }
  end

  -- Determine active save slot based on highest saveIndex across valid sectors 0-13
  local bestSlot = 1
  local maxSaveIndex = -1
  
  for slot = 0, 1 do
    local slotBase = slot * 14
    local slotValid = true
    local highestIndex = -1
    
    for s = 0, 13 do
      local sec = sectors[slotBase + s]
      if not sec.valid then
        slotValid = false
        break
      end
      if sec.saveIndex > highestIndex then
        highestIndex = sec.saveIndex
      end
    end

    if slotValid and highestIndex > maxSaveIndex then
      maxSaveIndex = highestIndex
      bestSlot = slot
    end
  end

  return {
    activeSlot = bestSlot,
    saveCount = maxSaveIndex,
    sectors = sectors
  }
end

return SaveManager
