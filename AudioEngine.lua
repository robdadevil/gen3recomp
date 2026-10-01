-- src/audio/game3/AudioEngine.lua
local AudioEngine = {}
AudioEngine.__index = AudioEngine

function AudioEngine.new()
  local self = setmetatable({}, AudioEngine)
  self.musicTrack = nil
  self.soundEffects = {}
  self.cries = {}
  self.masterVolume = 1.0
  self.directSoundChannels = {} -- PCM sample buffers
  return self
end

function AudioEngine:loadCry(speciesId, soundData)
  -- Store dynamic GBA Pokémon cry PCM sample
  self.cries[speciesId] = soundData
end

function AudioEngine:playCry(speciesId, pitchMod)
  local cry = self.cries[speciesId]
  if cry then
    pitchMod = pitchMod or 1.0
    -- Set pitch/rate for GBA dynamic cry modulation
    cry:setPitch(pitchMod)
    cry:stop()
    cry:play()
  end
end

function AudioEngine:playBGM(trackPath, loop)
  if self.musicTrack then
    self.musicTrack:stop()
  end

  self.musicTrack = love.audio.newSource(trackPath, "stream")
  self.musicTrack:setLooping(loop == nil and true or loop)
  self.musicTrack:setVolume(self.masterVolume)
  self.musicTrack:play()
end

function AudioEngine:playSFX(sfxName)
  local sfx = self.soundEffects[sfxName]
  if sfx then
    sfx:stop()
    sfx:play()
  end
end

function AudioEngine:setMasterVolume(volume)
  self.masterVolume = math.max(0.0, math.min(1.0, volume))
  if self.musicTrack then
    self.musicTrack:setVolume(self.masterVolume)
  end
end

return AudioEngine
