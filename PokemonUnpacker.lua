-- src/core/game3/PokemonUnpacker.lua
local PokemonUnpacker = {}

-- 24 permutations of the 4 substructures: G (Growth), A (Attacks), E (EVs/Condition), M (Miscellaneous)
local SUBSTRUCTURE_ORDERS = {
  [0]  = {"G", "A", "E", "M"}, {"G", "A", "M", "E"}, {"G", "E", "A", "M"}, {"G", "E", "M", "A"},
  [4]  = {"G", "M", "A", "E"}, {"G", "M", "E", "A"}, {"A", "G", "E", "M"}, {"A", "G", "M", "E"},
  [8]  = {"A", "E", "G", "M"}, {"A", "E", "M", "G"}, {"A", "M", "G", "E"}, {"A", "M", "E", "G"},
  [12] = {"E", "G", "A", "M"}, {"E", "G", "M", "A"}, {"E", "A", "G", "M"}, {"E", "A", "M", "G"},
  [16] = {"E", "M", "G", "A"}, {"E", "M", "A", "G"}, {"M", "G", "A", "E"}, {"M", "G", "E", "A"},
  [20] = {"M", "A", "G", "E"}, {"M", "A", "E", "G"}, {"M", "E", "G", "A"}, {"M", "E", "A", "G"}
}

local function readUint32(str, offset)
  local b1, b2, b3, b4 = string.byte(str, offset + 1, offset + 4)
  return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
end

local function readUint16(str, offset)
  local b1, b2 = string.byte(str, offset + 1, offset + 2)
  return b1 + (b2 * 256)
end

function PokemonUnpacker.unpack80Bytes(rawBytes)
  if #rawBytes < 80 then return nil, "Invalid data length" end

  local pid = readUint32(rawBytes, 0)
  local otId = readUint32(rawBytes, 4)
  local key = bit.bxor(pid, otId)

  -- Extract encrypted 48-byte block (bytes 32 to 79)
  local encryptedData = string.sub(rawBytes, 33, 80)
  local decryptedBytes = {}

  for i = 1, 48, 4 do
    local word = readUint32(encryptedData, i - 1)
    local decWord = bit.bxor(word, key)
    
    decryptedBytes[i]     = decWord % 256
    decryptedBytes[i + 1] = math.floor(decWord / 256) % 256
    decryptedBytes[i + 2] = math.floor(decWord / 65536) % 256
    decryptedBytes[i + 3] = math.floor(decWord / 16777216) % 256
  end

  local decStr = ""
  for i = 1, 48 do
    decStr = decStr .. string.char(decryptedBytes[i])
  end

  local order = SUBSTRUCTURE_ORDERS[pid % 24]
  local blocks = {}

  for idx, blockType in ipairs(order) do
    local blockOffset = (idx - 1) * 12
    blocks[blockType] = string.sub(decStr, blockOffset + 1, blockOffset + 12)
  end

  -- Parse Growth Block (G)
  local species = readUint16(blocks.G, 0)
  local heldItem = readUint16(blocks.G, 2)
  local exp = readUint32(blocks.G, 4)

  -- Parse Attack Block (A)
  local moves = {
    readUint16(blocks.A, 0), readUint16(blocks.A, 2),
    readUint16(blocks.A, 4), readUint16(blocks.A, 6)
  }

  -- Parse Effort/EV Block (E)
  local evs = {
    hp  = string.byte(blocks.E, 1),
    atk = string.byte(blocks.E, 2),
    def = string.byte(blocks.E, 3),
    spe = string.byte(blocks.E, 4),
    spa = string.byte(blocks.E, 5),
    spd = string.byte(blocks.E, 6)
  }

  -- Parse Misc Block (M)
  local ivWord = readUint32(blocks.M, 4)
  local ivs = {
    hp  = bit.band(ivWord, 0x1F),
    atk = bit.band(bit.rshift(ivWord, 5), 0x1F),
    def = bit.band(bit.rshift(ivWord, 10), 0x1F),
    spe = bit.band(bit.rshift(ivWord, 15), 0x1F),
    spa = bit.band(bit.rshift(ivWord, 20), 0x1F),
    spd = bit.band(bit.rshift(ivWord, 25), 0x1F),
    isEgg = bit.band(bit.rshift(ivWord, 30), 0x1) == 1
  }

  return {
    pid = pid,
    otId = otId,
    species = species,
    heldItem = heldItem,
    exp = exp,
    moves = moves,
    evs = evs,
    ivs = ivs
  }
end

return PokemonUnpacker
