local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'
local box2 = require 'vec.box2'

local Barrier = class(Object)
Barrier.sprite = 'barrier'
Barrier.solid = false
Barrier.timeOn = 3
Barrier.timeOff = 1
Barrier.damage = 2
Barrier.bbox = box2(-.3, 0, .3, 3)

function Barrier:pretouch(other, side)
	if self.shocking and other.takeDamage then
		other:takeDamage(self.damage, self, self, side)
	end
end

function Barrier:update(dt)
	if self.deactivated then
		self.shocking = false
	else
		local t = game.time % (self.timeOn + self.timeOff)
		self.shocking = t < self.timeOn
	end
	if self.shocking then
		self.sprite = 'barrier' -- class default
	else
		self.sprite = false	-- tell Object:draw not to draw anything
	end
end

return Barrier
