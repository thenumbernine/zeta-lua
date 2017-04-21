local class = require 'ext.class'
local GameObject = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'
local vec2 = require 'vec.vec2'

local SpinBlock = class(GameObject)
SpinBlock.sprite = 'spinblock'
SpinBlock.seq = 'spin'
SpinBlock.solid = false
SpinBlock.useGravity = false
SpinBlock.collidesWithWorld = false
SpinBlock.collidesWithObjects = false

function SpinBlock:init(args)
	SpinBlock.super.init(self, args)
	self.tilePos = vec2(args.tilePos[1], args.tilePos[2])
	self.spinEndTime = game.time + 5
end

-- TODO match vel to level vel <=> track moving levels
function SpinBlock:update(dt)
	SpinBlock.super.update(self, dt)
	if self.spinEndTime and self.spinEndTime <= game.time then
		local tile = game.level:getTile(self.tilePos[1], self.tilePos[2])

		local foundsolid
		if tile.objs then
			for _,obj in ipairs(tile.objs) do
				if obj.solid then
					foundsolid = true
					break
				end
			end
		end
		
		if foundsolid then
			self.spinEndTime = game.time + 5
		else
			self.spinEndTime = nil
			self.remove = true
			local SpinTile = require 'mario.script.tile.spin'
			setmetatable(tile, SpinTile)
		end
	end
end

return SpinBlock
