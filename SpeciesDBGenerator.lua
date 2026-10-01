-- src/data/game3/SpeciesDBGenerator.lua
local SpeciesDBGenerator = {}

-- Gen 3 Experience Growth Tables (Levels 1 to 100)
local EXP_CURVES = {
  Erratic = function(n)
    if n <= 50 then
      return math.floor((n^3 * (100 - n)) / 50)
    elseif n <= 68 then
      return math.floor((n^3 * (150 - n)) / 100)
    elseif n <= 98 then
      return math.floor((n^3 * math.floor((1911 - 10 * n) / 3)) / 500)
    else
      return math.floor((n^3 * (160 - n)) / 100)
    end
  end,
  Fast = function(n) return math.floor(0.8 * (n^3)) end,
  MediumFast = function(n) return math.floor(n^3) end,
  MediumSlow = function(n) return math.floor(1.2 * (n^3) - 15 * (n^2) + 100 * n - 140) end,
  Slow = function(n) return math.floor(1.25 * (n^3)) end,
  Fluctuating = function(n)
    if n <= 15 then
      return math.floor(n^3 * (math.floor((n + 1) / 3) + 24) / 50)
    elseif n <= 36 then
      return math.floor(n^3 * (n + 14) / 50)
    else
      return math.floor(n^3 * (math.floor(n / 2) + 32) / 50)
    end
  end
}

-- Primary Pokémon Registry
local RAW_SPECIES_DATA = {
  -- Kanto Starters (001-009)
  [1] = { name = "Bulbasaur", types = {"Grass", "Poison"}, base = {45,49,49,45,65,65}, catch = 45, exp = 64, rate = "MediumSlow", ev = {spa=1}, abilities = {"Overgrow"} },
  [2] = { name = "Ivysaur", types = {"Grass", "Poison"}, base = {60,62,63,60,80,80}, catch = 45, exp = 142, rate = "MediumSlow", ev = {spa=1, spd=1}, abilities = {"Overgrow"} },
  [3] = { name = "Venusaur", types = {"Grass", "Poison"}, base = {80,82,83,80,100,100}, catch = 45, exp = 208, rate = "MediumSlow", ev = {spa=2, spd=1}, abilities = {"Overgrow"} },
  [4] = { name = "Charmander", types = {"Fire"}, base = {39,52,43,65,60,50}, catch = 45, exp = 65, rate = "MediumSlow", ev = {spe=1}, abilities = {"Blaze"} },
  [5] = { name = "Charmeleon", types = {"Fire"}, base = {58,64,58,80,80,65}, catch = 45, exp = 142, rate = "MediumSlow", ev = {spe=1, spa=1}, abilities = {"Blaze"} },
  [6] = { name = "Charizard", types = {"Fire", "Flying"}, base = {78,84,78,100,109,85}, catch = 45, exp = 209, rate = "MediumSlow", ev = {spa=3}, abilities = {"Blaze"} },
  [7] = { name = "Squirtle", types = {"Water"}, base = {44,48,65,43,50,64}, catch = 45, exp = 66, rate = "MediumSlow", ev = {def=1}, abilities = {"Torrent"} },
  [8] = { name = "Wartortle", types = {"Water"}, base = {59,63,80,58,65,80}, catch = 45, exp = 143, rate = "MediumSlow", ev = {def=1, spd=1}, abilities = {"Torrent"} },
  [9] = { name = "Blastoise", types = {"Water"}, base = {79,83,100,78,85,105}, catch = 45, exp = 210, rate = "MediumSlow", ev = {spd=3}, abilities = {"Torrent"} },

  -- Hoenn Starters (252-260)
  [252] = { name = "Treecko", types = {"Grass"}, base = {40,45,35,70,65,55}, catch = 45, exp = 62, rate = "MediumSlow", ev = {spe=1}, abilities = {"Overgrow"} },
  [253] = { name = "Grovyle", types = {"Grass"}, base = {50,65,45,95,85,65}, catch = 45, exp = 141, rate = "MediumSlow", ev = {spe=2}, abilities = {"Overgrow"} },
  [254] = { name = "Sceptile", types = {"Grass"}, base = {70,85,65,120,105,85}, catch = 45, exp = 208, rate = "MediumSlow", ev = {spe=3}, abilities = {"Overgrow"} },
  [255] = { name = "Torchic", types = {"Fire"}, base = {45,60,40,45,70,50}, catch = 45, exp = 62, rate = "MediumSlow", ev = {spa=1}, abilities = {"Blaze"} },
  [256] = { name = "Combusken", types = {"Fire", "Fighting"}, base = {60,85,60,55,85,60}, catch = 45, exp = 142, rate = "MediumSlow", ev = {atk=1, spa=1}, abilities = {"Blaze"} },
  [257] = { name = "Blaziken", types = {"Fire", "Fighting"}, base = {80,120,70,80,110,70}, catch = 45, exp = 209, rate = "MediumSlow", ev = {atk=3}, abilities = {"Blaze"} },
  [258] = { name = "Mudkip", types = {"Water"}, base = {50,70,50,40,50,50}, catch = 45, exp = 62, rate = "MediumSlow", ev = {atk=1}, abilities = {"Torrent"} },
  [259] = { name = "Marshtomp", types = {"Water", "Ground"}, base = {70,85,70,50,60,70}, catch = 45, exp = 143, rate = "MediumSlow", ev = {atk=2}, abilities = {"Torrent"} },
  [260] = { name = "Swampert", types = {"Water", "Ground"}, base = {100,110,90,60,85,90}, catch = 45, exp = 210, rate = "MediumSlow", ev = {atk=3}, abilities = {"Torrent"} },

  -- Legendary Trio & Mythicals (382-386)
  [382] = { name = "Kyogre", types = {"Water"}, base = {100,100,90,90,150,140}, catch = 5, exp = 218, rate = "Slow", ev = {spa=3}, abilities = {"Drizzle"} },
  [383] = { name = "Groudon", types = {"Ground"}, base = {100,150,140,90,100,90}, catch = 5, exp = 218, rate = "Slow", ev = {atk=3}, abilities = {"Drought"} },
  [384] = { name = "Rayquaza", types = {"Dragon", "Flying"}, base = {105,150,90,95,150,90}, catch = 3, exp = 220, rate = "Slow", ev = {atk=2, spa=1}, abilities = {"Air Lock"} },
  [385] = { name = "Jirachi", types = {"Steel", "Psychic"}, base = {100,100,100,100,100,100}, catch = 3, exp = 215, rate = "Slow", ev = {hp=3}, abilities = {"Serene Grace"} },
  [386] = { name = "Deoxys", types = {"Psychic"}, base = {50,150,50,150,150,50}, catch = 3, exp = 215, rate = "Slow", ev = {atk=1, spa=1, spe=1}, abilities = {"Pressure"} }
}

-- Structural Factory & Data Normalizer
function SpeciesDBGenerator.generateDatabase()
  local db = {}

  for nationalDexId = 1, 386 do
    local raw = RAW_SPECIES_DATA[nationalDexId]
    
    -- Provide fallback placeholder structure for non-populated species IDs
    if not raw then
      raw = {
        name = "Pokémon #" .. tostring(nationalDexId),
        types = {"Normal"},
        base = {50, 50, 50, 50, 50, 50},
        catch = 255,
        exp = 50,
        rate = "MediumFast",
        ev = {hp = 1},
        abilities = {"Run Away"}
      }
    end

    local entry = {
      dexId = nationalDexId,
      name = raw.name,
      types = raw.types,
      baseStats = {
        hp  = raw.base[1],
        atk = raw.base[2],
        def = raw.base[3],
        spe = raw.base[4],
        spa = raw.base[5],
        spd = raw.base[6]
      },
      catchRate = raw.catch,
      expYield = raw.exp,
      growthRate = raw.rate,
      evYield = {
        hp  = raw.ev.hp or 0,
        atk = raw.ev.atk or 0,
        def = raw.ev.def or 0,
        spe = raw.ev.spe or 0,
        spa = raw.ev.spa or 0,
        spd = raw.ev.spd or 0
      },
      abilities = raw.abilities
    }

    -- Attach EXP calculator helper directly to species metatable
    function entry:getExpAtLevel(level)
      local calc = EXP_CURVES[self.growthRate]
      if calc then
        return calc(math.max(1, math.min(100, level)))
      end
      return EXP_CURVES["MediumFast"](level)
    end

    db[nationalDexId] = entry
  end

  return db
end

return SpeciesDBGenerator
