local class = require 'ext.class'
local GameObject = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'
local vec2 = require 'vec.vec2'

local SpinBlock = class(GameObject)
SpinBlock.sprite = 'spinblock'
SpinBlock.seq = 'spin'
SpinBlock.useGravity = false
SpinBlock.solidFlags = 0
SpinBlock.touchFlags = 0
SpinBlock.blockFlags = 0

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
		local x, y = self.tilePos:unpack()
		for _,obj in ipairs(game.objs) do
			if obj.solidFlags ~= 0 then
				local ixmin = math.floor(obj.pos[1] + obj.bbox.min[1])
				local ixmax = math.ceil(obj.pos[1] + obj.bbox.max[1])
				local iymin = math.floor(obj.pos[2] + obj.bbox.min[2])
				local iymax = math.ceil(obj.pos[2] + obj.bbox.max[2])
				if ixmin <= x and x <= ixmax
				and iymin <= y and y <= iymax
				then
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
			local spinTileType = assert(game.levelcfg.tileTypes:find(nil, function(tileType)
				return require 'mario.script.tile.spin':isa(tileType)
			end))
			game.level:setTile(self.tilePos[1], self.tilePos[2], spinTileType, 5)
		end
	end
end

return SpinBlock
