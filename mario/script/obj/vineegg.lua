local game = require 'base.script.singleton.game'

local VineEgg = behaviors(require 'base.script.obj.object',
	require 'mario.script.behavior.kickable')

VineEgg.sprite = 'egg'

local VineTile = require 'mario.script.tile.vine'
local vineTileType = game.levelcfg.tileTypes:find(nil, function(tileType)
	return VineTile.is(tileType)
end)
	
function VineEgg:update(...)
	local level = game.level
	
	if self.chomping then
		self.touchFlags = 0
		self.solidFlags = 0
		self.blockFlags = 0
		self.vel[1] = 0
		self.vel[2] = 10
		self.pos[1] = math.floor(self.pos[1]) + .5
	end

	VineEgg.super.update(self, ...)
	
	if self.chomping then
		local x, y = self.pos[1] - level.pos[1], self.pos[2] - level.pos[2]
		local tile = level:getTile(x, y)
		if (tile and tile.solid)
		or y > level.size[2]
		then
			self.remove = true
		else
			level:setTile(x,y, vineTileType, 0, 1+10)
			--TODO level:alignTileTemplates(x, y, x, y)
		end
	end
end

function VineEgg:playerBounce(player)
	self:hit()
end

function VineEgg:hit()
	if self.heldby then self.heldby:setHeld(nil) end
	self.sprite = 'pirahnaplant'
	self.chomping = true	-- TODO change metatable and reuse whatever with a pirahna block
	self.touchFlags = 0
	self.solidFlags = 0
	self.blockFlags = 0
	self.pos[2] = self.pos[2] + .5	-- in case we're on a slope ...
	self:playSound('sprout')	-- egghatch too?
	print'start chomping'
end

-- TODO hit precedences: hitA (block hit), hitB (shell hit), hitC (spin jump hit) ... and dif attacks use dif precedences
function VineEgg:hitByEnemy(other) self:hit(other) end
function VineEgg:hitByShell(other) self:hit(other) end
function VineEgg:hitByBlast(other) self:hit(other) end

return VineEgg
