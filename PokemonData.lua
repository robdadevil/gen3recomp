-- src/core/game3/PokemonData.lua
local PokemonData = {}

PokemonData.NATURES = {
  [0]  = { name = "Hardy",   up = nil, down = nil },
  [1]  = { name = "Lonely",  up = "atk", down = "def" },
  [2]  = { name = "Brave",   up = "atk", down = "spe" },
  [3]  = { name = "Adamant", up = "atk", down = "spa" },
  [4]  = { name = "Naughty", up = "atk", down = "spd" },
  [5]  = { name = "Bold",    up = "def", down = "atk" },
  [6]  = { name = "Docile",  up = nil, down = nil },
  [7]  = { name = "Relaxed", up = "def", down = "spe" },
  [8]  = { name = "Impish",  up = "def", down = "spa" },
  [9]  = { name = "Lax",     up = "def", down = "spd" },
  [10] = { name = "Timid",   up = "spe", down = "atk" },
  [11] = { name = "Hasty",   up = "spe", down = "def" },
  [12] = { name = "Serious", up = nil, down = nil },
  [13] = { name = "Jolly",   up = "spe", down = "spa" },
  [14] = { name = "Naive",   up = "spe", down = "spd" },
  [15] = { name = "Modest",  up = "spa", down = "atk" },
  [16] = { name = "Mild",    up = "spa", down = "def" },
  [17] = { name = "Quiet",   up = "spa", down = "spe" },
  [18] = { name = "Bashful", up = nil, down = nil },
  [19] = { name = "Rash",    up = "spa", down = "spd" },
  [20] = { name = "Calm",    up = "spd", down = "atk" },
  [21] = { name = "Gentle",  up = "spd", down = "def" },
  [22] = { name = "Sassy",   up = "spd", down = "spe" },
  [23] = { name = "Careful", up = "spd", down = "spa" },
  [24] = { name = "Quirky",  up = nil, down = nil },
}

function PokemonData.getNature(pid)
  return PokemonData.NATURES[pid % 25]
end

function PokemonData.isShiny(pid, otId, secretId)
  local p1 = math.floor(pid / 65536)
  local p2 = pid % 65536
  local shinyValue = bit.bxor(otId, secretId, p1, p2)
  return shinyValue < 8
end

function PokemonData.calculateStat(base, iv, ev, level, statKey, nature)
  if statKey == "hp" then
    if base == 1 then return 1 end -- Shedinja
    return math.floor(((2 * base + iv + math.floor(ev / 4)) * level) / 100) + level + 10
  end

  local raw = math.floor(((2 * base + iv + math.floor(ev / 4)) * level) / 100) + 5
  local mult = 1.0
  if nature.up == statKey then mult = 1.1 end
  if nature.down == statKey then mult = 0.9 end

  return math.floor(raw * mult)
end

return PokemonData
