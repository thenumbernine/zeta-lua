local class = require 'ext.class'
local game = require 'base.script.singleton.game'
local texsys = require 'base.script.singleton.texsys'
local modio = require 'base.script.singleton.modio'

local AnimationSystem = class()

function AnimationSystem:init(args)
	self.sprites = {}
end

-- don't call this until after GL has been initialized
function AnimationSystem:load(sprite)
	local dir = 'sprites/' .. (sprite.dir or '.') .. '/'
	if not sprite.seqs then sprite.seqs = {} end
	self.sprites[sprite.name] = sprite
	local newframes = {}
	for framename,srcframefile in pairs(sprite.frames) do
		-- mod search
		framefile = modio:find(dir .. srcframefile)
		if not framefile then
			error("unable to find file for sprite " .. dir .. srcframefile)
		end
	
		-- add in any single-frame sequences corresponding with individual frames
		if not sprite.seqs[framename] then
			sprite.seqs[framename] = {framename}
		end
		
		-- load the textures
		local tex = texsys:load(framefile)
		-- map the name=>file to name=>frame info, with frame info containing the name, file, texture
		--  texture size is in tex.width, tex.height
		newframes[framename] = {name=framename, file=framefile, tex=tex}
	end
	sprite.frames = newframes
end

function AnimationSystem:seqHasFinished(sprite, seqname, startTime)
	local sprite = self.sprites[sprite]
	if not sprite then error("failed to find sprite "..tostring(sprite)) end
	local seq = sprite.seqs[seqname]
	if not seq then
		print("failed to find sequence "..tostring(seqname))
		seq = sprite.seqs.stand
		if not seq then return end
	end
	
	local framenumber = game.time - (startTime or 0)
	if seq.freq then
		framenumber = framenumber * seq.freq
	elseif sprite.freq then
		framenumber = framenumber * sprite.freq
	end
	framenumber = framenumber + 1

	return framenumber >= #seq+1
end

function AnimationSystem:getTex(sprite, seqname, startTime)
	local sprite = self.sprites[sprite]
	if not sprite then error("failed to find sprite "..tostring(sprite)) end
	local seq = sprite.seqs[seqname]
	if not seq then
		print("failed to find sequence "..tostring(seqname))
		seq = sprite.seqs.stand
		if not seq then return end
	end
	
	local framenumber = game.time - (startTime or 0)
	if seq.freq then
		framenumber = framenumber * seq.freq
	elseif sprite.freq then
		framenumber = framenumber * sprite.freq
	end
	framenumber = (math.floor(framenumber) % #seq) + 1
	local framename = seq[framenumber]
	local frame = sprite.frames[framename]
	if not frame then error("failed to find frame named "..tostring(framename)) end
	return frame.tex
end

return AnimationSystem
