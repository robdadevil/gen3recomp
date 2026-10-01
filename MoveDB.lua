-- src/data/game3/MoveDB.lua
local MoveDB = {
  [1] = { name = "Pound", type = "Normal", power = 40, accuracy = 100, pp = 35, priority = 0 },
  [71] = { name = "Absorb", type = "Grass", power = 20, accuracy = 100, pp = 25, priority = 0, effect = "DRAIN_50" },
  [52] = { name = "Ember", type = "Fire", power = 40, accuracy = 100, pp = 25, priority = 0, effect = "BURN_10" },
  [55] = { name = "Water Gun", type = "Water", power = 40, accuracy = 100, pp = 25, priority = 0 },
  [98] = { name = "Quick Attack", type = "Normal", power = 40, accuracy = 100, pp = 30, priority = 1 },
  [237] = { name = "Hidden Power", type = "Normal", power = 0, accuracy = 100, pp = 15, priority = 0, effect = "CALC_HP" }
}

return MoveDB
