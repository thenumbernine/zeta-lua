local class = require 'ext.class'
local GameObject = require 'base.script.obj.object'
local VineTile = require 'mario.script.tile.vine'
local game = require 'base.script.singleton.game'

local VineEgg = class(GameObject)

VineEgg.sprite = 'egg'
VineEgg.canCarry = true

function VineEgg:update(...)
	local level = game.level
	
	if self.chomping then
		self.solid = false
		self.vel[1] = 0
		self.vel[2] = 10
		self.pos[1] = math.floor(self.pos[1]) + .5
	end

	VineEgg.super.update(self, ...)
	
	if self.chomping then
		local x, y = self.pos[1] - level.pos[1], self.pos[2] - level.pos[2]
		local tile = level:getTile(x, y)
		if tile and not tile.solid then
			tile:makeEmpty()	-- do this first to clear anything in it
			setmetatable(tile, VineTile)
			level:alignTileTemplates(x, y, x, y)
		else
			self.remove = true
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
	self.solid = false
	self.collidesWithWorld = false
	self.collidesWithObjects = false
	self.pos[2] = self.pos[2] + .5	-- in case we're on a slope ...
	self:playSound('sprout')	-- egghatch too?
end

-- TODO hit precedences: hitA (block hit), hitB (shell hit), hitC (spin jump hit) ... and dif attacks use dif precedences
function VineEgg:hitByEnemy(other) self:hit(other) end
function VineEgg:hitByShell(other) self:hit(other) end
function VineEgg:hitByBlast(other) self:hit(other) end

return VineEgg
