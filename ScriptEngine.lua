-- src/core/game3/ScriptEngine.lua
local ScriptEngine = {}
ScriptEngine.__index = ScriptEngine

function ScriptEngine.new(eventFlags, variables)
  local self = setmetatable({}, ScriptEngine)
  self.flags = eventFlags or {}
  self.vars = variables or {}
  self.scriptStack = {}
  self.isWaiting = false
  self.currentText = nil
  return self
end

function ScriptEngine:loadScript(bytecode)
  self.bytecode = bytecode
  self.pc = 1
  self.isWaiting = false
end

function ScriptEngine:step()
  if self.isWaiting or not self.bytecode or self.pc > #self.bytecode then
    return
  end

  local opcode = string.byte(self.bytecode, self.pc)
  self.pc = self.pc + 1

  if opcode == 0x21 then -- OP_MSGBOX
    local textId = string.byte(self.bytecode, self.pc) + (string.byte(self.bytecode, self.pc + 1) * 256)
    self.pc = self.pc + 2
    self.currentText = "Dialogue String #" .. textId
    self.isWaiting = true

  elseif opcode == 0x29 then -- OP_SETFLAG
    local flagId = string.byte(self.bytecode, self.pc) + (string.byte(self.bytecode, self.pc + 1) * 256)
    self.pc = self.pc + 2
    self.flags[flagId] = true

  elseif opcode == 0x2A then -- OP_CLEARFLAG
    local flagId = string.byte(self.bytecode, self.pc) + (string.byte(self.bytecode, self.pc + 1) * 256)
    self.pc = self.pc + 2
    self.flags[flagId] = false

  elseif opcode == 0x1A then -- OP_SETVAR
    local varId = string.byte(self.bytecode, self.pc) + (string.byte(self.bytecode, self.pc + 1) * 256)
    local val = string.byte(self.bytecode, self.pc + 2) + (string.byte(self.bytecode, self.pc + 3) * 256)
    self.pc = self.pc + 4
    self.vars[varId] = val

  elseif opcode == 0x5C then -- OP_APPLYMOVEMENT
    local npcId = string.byte(self.bytecode, self.pc)
    self.pc = self.pc + 1
    -- Trigger movement animation on NPC
    self.isWaiting = true

  elseif opcode == 0x27 then -- OP_END
    self.bytecode = nil
  end
end

function ScriptEngine:advanceText()
  if self.currentText then
    self.currentText = nil
    self.isWaiting = false
  end
end

return ScriptEngine
