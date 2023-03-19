local class = require 'ext.class'
local file = require 'ext.file'
local tolua = require 'ext.tolua'
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
	
	-- create implicit frames from all files
	for _,mod in ipairs(modio.search) do
		local dirobj = file(mod..'/'..dir)
		if dirobj:exists() then
			for framefile in dirobj:dir() do
				local framename, ext = file(framefile):getext()
				ext = ext:lower()
				if ext == 'png'
				or ext == 'tif'
				or ext == 'tiff'
				or ext == 'jpg'
				or ext == 'jpeg'
				or ext == 'bmp'
				then
					-- TODO make sure it's a file?  or at least has a proper extension?
					if not sprite.seqs[framename] then
						sprite.seqs[framename] = {framename}
					end

					local tex = texsys:load(mod..'/'..dir..'/'..framefile)
					newframes[framename] = {name=framename, file=framename, tex=tex}
				end
			end
		end
	end

	if sprite.frames then
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
	end
	
	sprite.frames = newframes
end

-- returns the sprite object, the seq object, and the frame #
function AnimationSystem:getInfo(spriteName, seqName, startTime)
	local sprite = self.sprites[spriteName]
	if not sprite then error("failed to find sprite "..tostring(spriteName)) end
	local seq = sprite.seqs[seqName]
	if not seq then
		print("failed to find sequence "..tostring(seqName))
		seq = sprite.seqs.stand
		if not seq then return end
	end
	
	local frameNumber = game.time - (startTime or 0)
	if seq.freq then
		frameNumber = frameNumber * seq.freq
	elseif sprite.freq then
		frameNumber = frameNumber * sprite.freq
	end
	frameNumber = frameNumber + 1

	return sprite, seq, frameNumber
end

function AnimationSystem:seqHasFinished(spriteName, seqName, startTime)
	local sprite, seq, frameNumber = self:getInfo(spriteName, seqName, startTime)
	return frameNumber >= #seq+1
end

function AnimationSystem:getFrame(spriteName, seqName, startTime)
	local sprite, seq, frameNumber = self:getInfo(spriteName, seqName, startTime)
	frameNumber = (math.floor(frameNumber - 1) % #seq) + 1
	local frameName = seq[frameNumber]
	return sprite.frames[frameName]
end

function AnimationSystem:getTex(spriteName, seqName, startTime)
	local frame = self:getFrame(spriteName, seqName, startTime)
	if not frame then 
		error("failed to find frame named "..tolua{
			spriteName = spriteName,
			seqName = seqName,
		}) 
	end
	return frame.tex
end

return AnimationSystem
