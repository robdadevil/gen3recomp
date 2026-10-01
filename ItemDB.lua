-- src/data/game3/ItemDB.lua
local ItemDB = {
  [1] = { name = "Master Ball", category = "Pokeball", catchRate = 255 },
  [2] = { name = "Ultra Ball", category = "Pokeball", catchRate = 2.0 },
  [3] = { name = "Great Ball", category = "Pokeball", catchRate = 1.5 },
  [4] = { name = "Poke Ball", category = "Pokeball", catchRate = 1.0 },
  [13] = { name = "Potion", category = "Medicine", healAmount = 20 },
  [14] = { name = "Antidote", category = "Medicine", curesStatus = "POISON" },
  [199] = { name = "Mach Bike", category = "KeyItem", speedMultiplier = 2.0 },
  [200] = { name = "Acro Bike", category = "KeyItem", allowBunnyHop = true }
}

return ItemDB
