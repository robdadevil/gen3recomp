-- src/core/game3/TextDecoder.lua
local TextDecoder = {}

-- GBA Pokémon proprietary character map subset
local CHAR_MAP = {
  [0x00] = " ",  [0x01] = "À", [0x02] = "Á", [0x03] = "Â", [0x04] = "Ç",
  [0xBB] = "A",  [0xBC] = "B", [0xBD] = "C", [0xBE] = "D", [0xBF] = "E",
  [0xC0] = "F",  [0xC1] = "G", [0xC2] = "H", [0xC3] = "I", [0xC4] = "J",
  [0xC5] = "K",  [0xC6] = "L", [0xC7] = "M", [0xC8] = "N", [0xC9] = "O",
  [0xCA] = "P",  [0xCB] = "Q", [0xCC] = "R", [0xCD] = "S", [0xCE] = "T",
  [0xCF] = "U",  [0xD0] = "V", [0xD1] = "W", [0xD2] = "X", [0xD3] = "Y",
  [0xD4] = "Z",  [0xD5] = "a", [0xD6] = "b", [0xD7] = "c", [0xD8] = "d",
  [0xD9] = "e",  [0xDA] = "f", [0xDB] = "g", [0xDC] = "h", [0xDD] = "i",
  [0xDE] = "j",  [0xDF] = "k", [0xE0] = "l", [0xE1] = "m", [0xE2] = "n",
  [0xE3] = "o",  [0xE4] = "p", [0xE5] = "q", [0xE6] = "r", [0xE7] = "s",
  [0xE8] = "t",  [0xE9] = "u", [0xEA] = "v", [0xEB] = "w", [0xEC] = "x",
  [0xED] = "y",  [0xEE] = "z", [0xA1] = "0", [0xA2] = "1", [0xA3] = "2",
  [0xA4] = "3",  [0xA5] = "4", [0xA6] = "5", [0xA7] = "6", [0xA8] = "7",
  [0xA9] = "8",  [0xAA] = "9", [0xAB] = "!", [0xAC] = "?", [0xAD] = ".",
  [0xAE] = "-",  [0xFE] = "\n", [0xFF] = "" -- 0xFF is End of String
}

function TextDecoder.decode(bytes)
  local result = ""
  for i = 1, #bytes do
    local charByte = string.byte(bytes, i)
    if charByte == 0xFF then break end -- Stop at terminator
    
    local char = CHAR_MAP[charByte] or " "
    result = result .. char
  end
  return result
end

return TextDecoder
