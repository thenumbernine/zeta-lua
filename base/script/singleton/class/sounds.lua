local audio = require 'base.script.singleton.audio'
local AudioBuffer = require 'audio.buffer'
local modio = require 'base.script.singleton.modio'

local SoundSystem = class()

function SoundSystem:init()
	self.sounds = {}
end

function SoundSystem:load(filename)
	local searchfilename = 'sound/'..filename
	filename = modio:find(searchfilename)
	if not filename then error("warning: couldn't find sound file "..searchfilename) end
	
	local sound = self.sounds[filename]
	if not sound then
		sound = AudioBuffer(filename)
		self.sounds[filename] = sound
	end
	return sound
end

return SoundSystem
