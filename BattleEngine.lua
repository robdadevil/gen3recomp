-- src/core/game3/BattleEngine.lua
local AbilityDB = require("src.data.game3.AbilityDB")
local StatusEngine = require("src.core.game3.StatusEngine")

local BattleEngine = {}
BattleEngine.__index = BattleEngine

function BattleEngine.new(isDoubleBattle)
  local self = setmetatable({}, BattleEngine)
  self.isDoubleBattle = isDoubleBattle or false
  self.weather = "NONE" -- NONE, RAIN, SUN, SANDSTORM, HAIL
  self.weatherTurns = 0
  self.suppressWeather = false
  self.fieldUnits = {} -- Active battlers on field
  self.turnQueue = {}
  return self
end

--------------------------------------------------------------------------------
-- 1. HELPERS & WEATHER MANAGEMENT
--------------------------------------------------------------------------------

function BattleEngine:getAbility(pokemon)
  if not pokemon or pokemon.currentHp <= 0 then return nil end
  return AbilityDB[pokemon.ability]
end

function BattleEngine:setWeather(weatherType, duration)
  self.weather = weatherType
  self.weatherTurns = duration or 5
end

function BattleEngine:checkWeatherSuppression()
  self.suppressWeather = false
  for _, mon in ipairs(self.fieldUnits) do
    local ab = self:getAbility(mon)
    if ab and ab.suppressWeather then
      self.suppressWeather = true
      break
    end
  end
end

function BattleEngine:getEffectiveSpeed(pokemon)
  local speed = pokemon.stats.spe

  -- Apply paralysis status reduction via StatusEngine
  speed = StatusEngine.getSpeedModifier(pokemon, speed)

  local ab = self:getAbility(pokemon)

  -- Weather-based speed multipliers
  if not self.suppressWeather then
    if self.weather == "RAIN" and pokemon.ability == "Swift Swim" then
      speed = speed * 2
    elseif self.weather == "SUN" and pokemon.ability == "Chlorophyll" then
      speed = speed * 2
    end
  end

  -- Ability speed modifiers (e.g., Chlorophyll/Swift Swim overrides or items)
  if ab and ab.modifySpeed then
    speed = ab.modifySpeed(pokemon, speed)
  end

  return math.floor(speed)
end

--------------------------------------------------------------------------------
-- 2. TURN ORDER & PRIORITY RESOLUTION
--------------------------------------------------------------------------------

function BattleEngine:calculatePriority(action1, action2)
  -- Priority brackets first (-7 to +6)
  if action1.priority ~= action2.priority then
    return action1.priority > action2.priority
  end

  -- Speed tie-breaker modified by Statuses/Abilities/Items/Weather
  local speed1 = self:getEffectiveSpeed(action1.user)
  local speed2 = self:getEffectiveSpeed(action2.user)

  if speed1 == speed2 then
    return math.random() > 0.5
  end
  return speed1 > speed2
end

--------------------------------------------------------------------------------
-- 3. BATTLE HOOKS & TURN EXECUTION
--------------------------------------------------------------------------------

function BattleEngine:onSwitchIn(pokemon, target)
  if not pokemon or pokemon.currentHp <= 0 then return end
  table.insert(self.fieldUnits, pokemon)

  self:checkWeatherSuppression()
  local ab = self:getAbility(pokemon)

  if ab and ab.onSwitchIn then
    ab.onSwitchIn(pokemon, target, self)
  end
end

function BattleEngine:onTurnStart(actions)
  self:checkWeatherSuppression()

  -- Execute On-Turn-Start abilities (e.g., Speed Boost, Weather activations)
  for _, mon in ipairs(self.fieldUnits) do
    local ab = self:getAbility(mon)
    if ab and ab.onTurnStart then
      ab.onTurnStart(mon, self)
    end
  end
end

function BattleEngine:executeTurn(actions)
  self:onTurnStart(actions)

  -- Sort action queue by priority and effective speed
  table.sort(actions, function(a, b)
    return self:calculatePriority(a, b)
  end)

  for _, action in ipairs(actions) do
    if action.user.currentHp > 0 then
      self:processAction(action)
    end
  end

  self:endTurnPhase()
end

--------------------------------------------------------------------------------
-- 4. ACTION PROCESSING & DAMAGE CALCULATIONS
--------------------------------------------------------------------------------

function BattleEngine:processAction(action)
  local move = action.move
  local user = action.user
  local target = action.target

  if user.currentHp <= 0 then return end

  -- Status check (Sleep/Freeze/Paralysis move lock)
  if not StatusEngine.canExecuteMove(user, move) then
    return
  end

  -- Target Immunity Check via Ability (e.g., Levitate, Wonder Guard, Volt Absorb)
  local targetAbility = self:getAbility(target)
  if targetAbility and targetAbility.isImmuneTo then
    if targetAbility.isImmuneTo(move.type, move, user) then
      print(target.name .. "'s " .. target.ability .. " makes it immune to " .. move.name .. "!")
      return
    end
  end

  local movePower = move.power
  local userAbility = self:getAbility(user)

  -- Ability power modifications (e.g., Blaze/Torrent at low HP, Huge Power)
  if userAbility and userAbility.modifyMovePower then
    movePower = userAbility.modifyMovePower(user, move, movePower)
  end

  -- Weather Damage Modifications
  if not self.suppressWeather then
    if self.weather == "RAIN" then
      if move.type == "Water" then movePower = movePower * 1.5 end
      if move.type == "Fire" then movePower = movePower * 0.5 end
    elseif self.weather == "SUN" then
      if move.type == "Fire" then movePower = movePower * 1.5 end
      if move.type == "Water" then movePower = movePower * 0.5 end
    end
  end

  -- Double Battle multi-target penalty
  if self.isDoubleBattle and action.isMultiTarget then
    movePower = math.floor(movePower * 0.75)
  end

  -- Execute Damage
  if movePower > 0 then
    -- Physical Attack calculation incorporating status modifiers (e.g. Burn halving Attack)
    local userAtk = user.stats.atk
    if move.category == "Physical" or not move.category then
      userAtk = StatusEngine.getAttackModifier(user, userAtk)
    end

    local damage = math.max(1, math.floor((((2 * user.level / 5 + 2) * movePower * (userAtk / target.stats.def)) / 50) + 2))
    target.currentHp = math.max(0, target.currentHp - damage)

    -- On-Hit Ability Trigger (e.g., Static, Rough Skin, Contact abilities)
    if targetAbility and targetAbility.onHit then
      targetAbility.onHit(target, user, move, damage, self)
    end
  end
end

--------------------------------------------------------------------------------
-- 5. TURN-END PHASE
--------------------------------------------------------------------------------

function BattleEngine:endTurnPhase()
  -- Execute status condition damage (Burn, Poison, Bad Poison) and turn-end abilities
  for _, mon in ipairs(self.fieldUnits) do
    if mon.currentHp > 0 then
      StatusEngine.applyTurnEndDamage(mon)

      local ab = self:getAbility(mon)
      if ab and ab.onTurnEnd then
        ab.onTurnEnd(mon, self)
      end
    end
  end

  -- Weather countdown
  if not self.suppressWeather and self.weatherTurns > 0 then
    self.weatherTurns = self.weatherTurns - 1
    if self.weatherTurns == 0 then
      self.weather = "NONE"
      print("The weather cleared up.")
    end
  end
end

return BattleEngine
