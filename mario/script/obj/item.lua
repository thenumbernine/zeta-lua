local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local Mario = require 'mario.script.obj.mario'

--[[
itemClass is the class of the MarioItem that touching this gives you
--]]

local Item = class(Object)
Item.solid = false

function Item:touch(other, side)
	if other:isa(Mario) then
		other:growBig()
		if self.itemClass then other.item = self:itemClass() end
		self.remove = true
	end
end


return Item
