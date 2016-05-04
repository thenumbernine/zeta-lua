local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local Hero = require 'zeta.script.obj.hero'

local Item = class(Object)
Item.solid = false

function Item:touch(other, side)
	if self.remove then return end
	if other:isa(Hero) then
		self:give(other, side)
		self:playSound('powerup')
		self.remove = true
	end
end

return Item
