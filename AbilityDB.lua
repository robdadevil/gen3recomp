-- src/data/game3/AbilityDB.lua
local AbilityDB = {
  ["Intimidate"] = {
    onSwitchIn = function(user, target)
      if target and target.stats then
        target.statStages.atk = math.max(-6, target.statStages.atk - 1)
      end
    end
  },
  ["Levitate"] = {
    isImmuneTo = function(moveType)
      return moveType == "Ground"
    end
  },
  ["Speed Boost"] = {
    onTurnEnd = function(user)
      user.statStages.spe = math.min(6, user.statStages.spe + 1)
    end
  },
  ["Air Lock"] = {
    suppressWeather = true
  }
}

return AbilityDB
