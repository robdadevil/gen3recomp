-- src/data/game3/SpeciesDB.lua
local SpeciesDB = {
  [252] = {
    name = "Treecko",
    types = {"Grass"},
    baseStats = { hp = 40, atk = 45, def = 35, spe = 70, spa = 65, spd = 55 },
    catchRate = 45,
    expYield = 62,
    growthRate = "MediumSlow",
    abilities = {"Overgrow"}
  },
  [255] = {
    name = "Torchic",
    types = {"Fire"},
    baseStats = { hp = 45, atk = 60, def = 40, spe = 45, spa = 70, spd = 50 },
    catchRate = 45,
    expYield = 62,
    growthRate = "MediumSlow",
    abilities = {"Blaze"}
  },
  [258] = {
    name = "Mudkip",
    types = {"Water"},
    baseStats = { hp = 50, atk = 70, def = 50, spe = 40, spa = 50, spd = 50 },
    catchRate = 45,
    expYield = 62,
    growthRate = "MediumSlow",
    abilities = {"Torrent"}
  },
  [384] = {
    name = "Rayquaza",
    types = {"Dragon", "Flying"},
    baseStats = { hp = 105, atk = 150, def = 90, spe = 95, spa = 150, spd = 90 },
    catchRate = 3,
    expYield = 220,
    growthRate = "Slow",
    abilities = {"Air Lock"}
  }
}

return SpeciesDB
