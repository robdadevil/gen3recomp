-- src/core/game3/StatusEngine.lua
local StatusEngine = {}

local STATUS_EFFECTS = {
  SLP = {
    onBeforeMove = function(pokemon)
      if pokemon.statusTurns > 0 then
        pokemon.statusTurns = pokemon.statusTurns - 1
        if pokemon.statusTurns > 0 then
          print(pokemon.name .. " is fast asleep!")
          return false -- Prevents move execution
        end
        pokemon.status = "NONE"
        print(pokemon.name .. " woke up!")
      end
      return true
    end
  },
  FRZ = {
    onBeforeMove = function(pokemon, move)
      -- Fire-type moves immediately thaw the user
      if move and move.type == "Fire" then
        pokemon.status = "NONE"
        print(pokemon.name .. " melted the ice with " .. move.name .. "!")
        return true
      end
      -- 20% chance to thaw per turn
      if math.random() < 0.20 then
        pokemon.status = "NONE"
        print(pokemon.name .. " thawed out!")
        return true
      end
      print(pokemon.name .. " is frozen solid!")
      return false
    end
  },
  PAR = {
    modifySpeed = function(speed)
      return math.floor(speed * 0.25) -- Gen 3 reduces speed by 75%
    end,
    onBeforeMove = function(pokemon)
      if math.random() < 0.25 then
        print(pokemon.name .. " is fully paralyzed!")
        return false
      end
      return true
    end
  },
  BRN = {
    modifyAttack = function(atk)
      return math.floor(atk * 0.5) -- Burns halve physical attack power
    end,
    onTurnEnd = function(pokemon)
      local damage = math.max(1, math.floor(pokemon.maxHp / 8))
      pokemon.currentHp = math.max(0, pokemon.currentHp - damage)
      print(pokemon.name .. " is hurt by its burn! (-" .. damage .. " HP)")
    end
  },
  PSN = {
    onTurnEnd = function(pokemon)
      local damage = math.max(1, math.floor(pokemon.maxHp / 8))
      pokemon.currentHp = math.max(0, pokemon.currentHp - damage)
      print(pokemon.name .. " is hurt by poison! (-" .. damage .. " HP)")
    end
  },
  TOX = { -- Toxic / Badly Poisoned
    onTurnEnd = function(pokemon)
      pokemon.toxicCounter = (pokemon.toxicCounter or 1) + 1
      local damage = math.max(1, math.floor((pokemon.maxHp * pokemon.toxicCounter) / 16))
      pokemon.currentHp = math.max(0, pokemon.currentHp - damage)
      print(pokemon.name .. " is hurt by poison! (-" .. damage .. " HP)")
    end
  }
}

function StatusEngine.canExecuteMove(pokemon, move)
  if not pokemon or pokemon.status == "NONE" then return true end
  local handler = STATUS_EFFECTS[pokemon.status]
  if handler and handler.onBeforeMove then
    return handler.onBeforeMove(pokemon, move)
  end
  return true
end

function StatusEngine.applyTurnEndDamage(pokemon)
  if not pokemon or pokemon.currentHp <= 0 then return end
  local handler = STATUS_EFFECTS[pokemon.status]
  if handler and handler.onTurnEnd then
    handler.onTurnEnd(pokemon)
  end
end

function StatusEngine.getSpeedModifier(pokemon, currentSpeed)
  if not pokemon or pokemon.status == "NONE" then return currentSpeed end
  local handler = STATUS_EFFECTS[pokemon.status]
  if handler and handler.modifySpeed then
    return handler.modifySpeed(currentSpeed)
  end
  return currentSpeed
end

function StatusEngine.getAttackModifier(pokemon, currentAtk)
  if not pokemon or pokemon.status == "NONE" then return currentAtk end
  local handler = STATUS_EFFECTS[pokemon.status]
  if handler and handler.modifyAttack then
    return handler.modifyAttack(currentAtk)
  end
  return currentAtk
end

return StatusEngine
